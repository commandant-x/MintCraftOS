#!/usr/bin/env python3
"""Plot selected before/after traces from test-sputnik-twin.py outputs."""
import argparse
import csv
import json
import os
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--before', type=Path, required=True)
parser.add_argument('--after', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--resonance', action='store_true')
args = parser.parse_args()
before_metadata = json.loads((args.before / 'summary.json').read_text())
after_metadata = json.loads((args.after / 'summary.json').read_text())
assumptions = after_metadata['assumptions']
assert assumptions == before_metadata['assumptions'], 'Compare identical vehicle parameters'
args.output.parent.mkdir(parents=True, exist_ok=True)
os.environ.setdefault('MPLCONFIGDIR', '/tmp/mintcraft-twin-matplotlib')
os.environ.setdefault('XDG_CACHE_HOME', '/tmp/mintcraft-twin-cache')
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

selected = [('level_drop_2ms', 'Chute à plat, 2 m/s'),
            ('tilt_roll_5deg', 'Départ incliné, roulis 5°'),
            ('diagonal_then_brake', 'Diagonale puis maintien'),
            ('inertia_quarter', 'Inerties × 0,25 — échec persistant')]
if args.resonance:
    selected = [('sustained_forward', 'Réponse à W puis freinage'),
                ('inertia_quarter', 'Inerties × 0,25'),
                ('inertia_eighth', 'Inerties × 0,125'),
                ('inertia_quarter_delay2', 'Inerties × 0,25 + retard')]
fig, axes = plt.subplots(3, 4, figsize=(17, 9), sharex='col')
for col, (name, title) in enumerate(selected):
    axes[0, col].set_title(title, fontsize=10)
    for directory, label, color in [(args.before, before_metadata['version'], '#c13b32'), (args.after, after_metadata['version'], '#167aab')]:
        with (directory / (name + '.csv')).open() as source:
            data = list(csv.DictReader(source))
        t = [float(r['time']) for r in data]
        primary = [(float(r['vx']) ** 2 + float(r['vz']) ** 2) ** .5 for r in data] if args.resonance else [float(r['y']) - float(r['target_y']) for r in data]
        curves = [primary,
                  [float(r['tilt']) for r in data],
                  [max(float(r['r' + str(i)]) for i in range(1, 5))
                   - min(float(r['r' + str(i)]) for i in range(1, 5)) for r in data]]
        for row, curve in enumerate(curves):
            axes[row, col].plot(t, curve, color=color, linewidth=.9, label=label)
    axes[1, col].axhline(25, color='gray', linestyle='--', linewidth=.6)
    for row in range(3):
        axes[row, col].grid(alpha=.2)
    axes[2, col].set_xlabel('Temps (s)')
axes[0, 0].set_ylabel('Vitesse horizontale (m/s)' if args.resonance else 'Altitude − cible (m)')
axes[1, 0].set_ylabel('Inclinaison (°)')
axes[2, 0].set_ylabel('Écart max−min des signaux 0..15')
axes[0, 0].legend()
arm_x = abs(assumptions['rotors_local_m'][0][0])
arm_z = abs(assumptions['rotors_local_m'][0][2])
fig.suptitle(f'Banc numérique 3D : {assumptions["mass_kg"]:g} kg, demi-largeur {arm_x:g} m, demi-longueur {arm_z:g} m\n'
             'Inerties supposées — comparaison de simulation, pas une certification de vol', fontsize=13)
fig.tight_layout()
fig.savefig(args.output, dpi=130)
plt.close(fig)
print(args.output)
