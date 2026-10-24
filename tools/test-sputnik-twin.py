#!/usr/bin/env python3
"""Run shipped Sputnik Lua nodes against an independent, parameterised 6DOF plant."""
import argparse
import csv
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--cosmonautics-jar', type=Path, required=True)
parser.add_argument('--java-home', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--mass', type=float, default=65)
parser.add_argument('--arm-x', type=float, default=3)
parser.add_argument('--arm-z', type=float, default=2)
parser.add_argument('--height', type=float, default=1)
parser.add_argument('--ix', type=float, default=250)
parser.add_argument('--iy', type=float, default=400)
parser.add_argument('--iz', type=float, default=230)
parser.add_argument('--controller-file', type=Path, help='Explicit alternate controller for before/after comparison')
parser.add_argument('--controller-version', help='Required label for alternate controller')
parser.add_argument('--cases', help='Comma-separated scenario names; omit for the whole suite')
args = parser.parse_args()
profile = dict(mass=args.mass, armX=args.arm_x, armZ=args.arm_z, height=args.height, ix=args.ix, iy=args.iy, iz=args.iz)
assert all(math.isfinite(v) for v in profile.values())
assert all(v > 0 for k, v in profile.items() if k != 'height')
assert not args.controller_file or args.controller_version, 'Label the alternate controller version'
controller = (args.controller_file or ROOT / 'platforms/sputnik/dist/mintcraft-quad-control.lua').resolve()
args.output = args.output.resolve()
args.output.mkdir(parents=True, exist_ok=True)
manifest = json.loads((ROOT / 'platforms/sputnik/dist/manifest.json').read_text())
version = args.controller_version if args.controller_file else manifest['version']
digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
assert digest(args.cosmonautics_jar) == manifest['hostJarSha256'], 'Audit this host version first'
# Test exactly the generated package: do not silently regenerate/replace it here.
for name, record in manifest['artifacts'].items():
    assert digest(ROOT / 'platforms/sputnik/dist' / name) == record['sha256'], name
with tempfile.TemporaryDirectory(prefix='sputnik-twin-') as tmp:
    folder = Path(tmp)
    runtime = folder / 'runtime.jar'
    with zipfile.ZipFile(args.cosmonautics_jar) as source, zipfile.ZipFile(runtime, 'w') as target:
        for name in source.namelist():
            if name.startswith('dev/devce/rocketnautics/shaded/luaj/') and name.endswith('.class'):
                target.writestr(name, source.read(name))
    subprocess.run([str(args.java_home / 'bin/javac'), '-cp', str(runtime), '-d', str(folder),
                    str(ROOT / 'tools/VerifySputnikLua.java')], cwd=ROOT, check=True)
    bootstrap = folder / 'bootstrap.lua'
    bootstrap.write_text('MINTCRAFT_TWIN_OUTPUT=' + json.dumps(str(args.output)) + '\n'
                         + 'MINTCRAFT_TWIN_PROFILE={' + ','.join(k + '=' + repr(v) for k, v in profile.items()) + '}\n'
                         + 'MINTCRAFT_TWIN_CONTROLLER=' + json.dumps(str(controller)) + '\n'
                         + ('MINTCRAFT_TWIN_CASES={' + ','.join(json.dumps(n) for n in args.cases.split(',')) + '}\n' if args.cases else ''))
    command = [str(args.java_home / 'bin/java'), '-cp', str(folder) + os.pathsep + str(runtime),
               'VerifySputnikLua', str(bootstrap), 'tools/sputnik-digital-twin.lua']
    with (args.output / 'runtime.log').open('w') as log:
        subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)
rows = list(csv.DictReader((args.output / 'summary.csv').open()))
nominal = [r for r in rows if r['stress'] == 'false']
metadata = {
    'edition': manifest['edition'], 'version': version,
    'base_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
    'controller_sha256': digest(controller),
    'plant_sha256': digest(ROOT / 'tools/sputnik-digital-twin.lua'),
    'host_sha256': digest(args.cosmonautics_jar),
    'scope': 'Independent surrogate, not a measured replica or Minecraft world test',
    'assumptions': {
        'mass_kg': args.mass, 'inertia_diagonal_kg_m2': [args.ix, args.iy, args.iz],
        'initial_altitude_m': 80,
        'rotors_local_m': [[sx * args.arm_x, args.height, sz * args.arm_z] for sx, sz in [(-1, 1), (1, 1), (-1, -1), (1, -1)]],
        'source_rpm': 256, 'gravity_ms2': 11, 'spool_alpha_per_50ms': .15,
        'controller_hz': 20, 'rigid_body_hz': 200, 'radio_delay_ticks': 1,
        'transmission_rpm': 'signal 0:256; integer 1..15:256*(15-signal)/16',
        'thrust': 'rpm * pressure * clamp(1 - axial_velocity/(0.1*rpm), 0, 1)',
        'pressure': '1m linear interpolation of 421 samples from actual Java Sable oracle',
        'baseline_linear_angular_damping_s_1': .05,
    },
    'criteria': {'active_throughout': True, 'final_altitude_error_m_lt': .3,
                 'final_speed_ms_lt': .2, 'final_horizontal_error_m_lt': .3,
                 'maximum_tilt_deg_lt': 25, 'last_10s_tilt_rms_deg_lt': 2, 'last_10s_speed_rms_ms_lt': .2},
    'limitations': ['Mass and dimensions are user parameters; inertia/COM/rotor response not measured',
                    'No collision, terrain, joints, constraints or Create stress network solver',
                    'No full inertia tensor, rotor gyroscopic torques or ground effect',
                    'Radio delay and linear/angular airframe drag are scenario assumptions',
                    'Weak rotor, shifted COM, swapped mapping and inverted transmission are deliberate model mismatches'],
    'scenarios': rows,
}
(args.output / 'summary.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + '\n')
passed = sum(r['status'] == 'PASS' for r in nominal)
text = [f'# Sputnik {version} — banc numérique 3D', '',
        '**Simulation indépendante paramétrée ; pas un jumeau mesuré du véhicule du joueur.**', '',
        f'Cas de référence réussis : **{passed}/{len(nominal)}**. '
        'Les cas « stress » modifient volontairement les hypothèses du contrôleur ; '
        'ils ne sont pas exclus des résultats.', '',
        'Les véritables scripts Lua livrés sont exécutés dans le LuaJ de Cosmonautics. '
        'La plante utilise quaternion, forces aux quatre points, couples et inerties, '
        'dynamique rigide à 200 Hz, régime retardé à 20 Hz et propagation du graphe à un tick. '
        'La plante continue après un défaut : le repli ne fige pas le véhicule.', '',
        'Critères : actif tout le long, erreur finale altitude < 0,3 m, vitesse finale < 0,2 m/s, '
        'erreur horizontale finale < 0,3 m et inclinaison maximale < 25°. '
        'Sur les dix dernières secondes : inclinaison RMS < 2° et vitesse RMS < 0,2 m/s. '
        'Une réussite ne borne pas les excursions transitoires : elles sont indiquées séparément.', '',
        '| Scénario | Stress | Résultat | Erreur finale (m) | Inclinaison max (°) | RMS angle (°) | RMS vitesse (m/s) | T50 (s) | Défaut |',
        '| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |']
for r in rows:
    text.append(f'| {r["scenario"]} | {r["stress"]} | {r["status"]} | '
                f'{float(r["final_altitude_error_m"]):.3f} | '
                f'{float(r["max_tilt_deg"]):.2f} | {float(r["tail_tilt_rms_deg"]):.3f} | '
                f'{float(r["tail_speed_rms_ms"]):.3f} | {float(r["response50_s"]):.2f} | '
                f'{r["first_fault"].replace("|", "/") or "—"} |')
text += ['', f'Paramètres de base : {args.mass:g} kg, inerties diagonales supposées {args.ix:g}/{args.iy:g}/{args.iz:g} kg·m², '
         f'demi-largeur {args.arm_x:g} m, demi-longueur {args.arm_z:g} m, rotors à {args.height:+g} m de Sputnik, altitude initiale Y=80, centre de masse centré, '
         'petits rotors identiques vers le haut, 256 RPM, gravité 11, retard radio 1 tick. '
         'Les amortissements 0,05 s⁻¹ sont hypothétiques ; un cas les supprime complètement.', '',
         'Les signaux 0..15 sont des réductions : 0 = 256 RPM, 1 = 224 RPM et 15 = arrêt. '
         'Les traces CSV contiennent les signaux réellement appliqués par la plante et les quatre régimes.', '',
         'RMS : moyenne quadratique sur les dix dernières secondes. T50 : délai depuis l’appui W '
         'pour atteindre 1 m/s vers l’avant (50 % de la consigne de 2 m/s) ; −1 signifie non atteint '
         'pendant l’appui ou non applicable. L’erreur maximale transitoire reste disponible dans le CSV.', '',
         'La masse et les dimensions sont des paramètres déclarés ; les inerties, le centre de masse et la mécanique ne sont pas mesurés. '
         'Le moteur physique Sable et le réseau cinétique Create ne sont pas lancés. '
         'Aucune certitude de vol en jeu ni qualification autopilote ne résulte de ce rapport.', '',
         f'Contrôleur SHA256 : `{metadata["controller_sha256"]}`.',
         f'Plante SHA256 : `{metadata["plant_sha256"]}`.', '']
(args.output / 'REPORT.md').write_text('\n'.join(text))
# Standalone figure; traces and report remain useful without plotting support.
try:
    os.environ.setdefault('MPLCONFIGDIR', str(args.output / '.matplotlib'))
    os.environ.setdefault('XDG_CACHE_HOME', str(args.output / '.cache'))
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    selected = ['level_drop_2ms', 'cold_rotors', 'tilt_pitch_5deg', 'com_offset_10cm']
    fig, axes = plt.subplots(3, 4, figsize=(17, 9), sharex='col')
    for col, name in enumerate(selected):
        data = list(csv.DictReader((args.output / (name + '.csv')).open()))
        t = [float(r['time']) for r in data]
        axes[0, col].set_title(name.replace('_', ' '))
        axes[0, col].plot(t, [float(r['y']) - float(r['target_y']) for r in data])
        axes[1, col].plot(t, [float(r['tilt']) for r in data])
        axes[1, col].axhline(25, color='r', linestyle='--', linewidth=.7)
        for i in range(1, 5):
            axes[2, col].plot(t, [float(r['r' + str(i)]) for r in data], linewidth=.6, label=str(i))
        for row in range(3):
            axes[row, col].grid(alpha=.2)
        axes[2, col].set_xlabel('Temps (s)')
    axes[0, 0].set_ylabel('Altitude − cible (m)')
    axes[1, 0].set_ylabel('Inclinaison (°)')
    axes[2, 0].set_ylabel('Signaux transmission 0..15')
    axes[2, 3].legend(title='Rotor', ncol=4, loc='upper right', fontsize=7)
    fig.suptitle('Sputnik — modèle numérique provisoire, hypothèses non mesurées en jeu')
    fig.tight_layout()
    fig.savefig(args.output / 'flight-traces.png', dpi=130)
    plt.close(fig)
except ImportError:
    pass
print('\n'.join(text[:5]))
print('Report:', args.output / 'REPORT.md')
