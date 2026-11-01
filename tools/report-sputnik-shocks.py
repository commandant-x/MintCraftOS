#!/usr/bin/env python3
"""Score real Minecraft impulses without counting fixture capture as recovery."""
import argparse
import csv
import hashlib
import json
import math
import re
import shutil
from pathlib import Path

LABELS = {
    'side5': 'Choc latéral +5 m/s', 'side12': 'Choc latéral +12 m/s',
    'down8': 'Chute : −8 m/s', 'up8': 'Projection : +8 m/s',
    'roll2': 'Rotation locale Z : +2 rad/s',
    'pitch2': 'Rotation locale X : +2 rad/s',
    'combined': 'Choc translation + rotation',
    'inversion': 'Rotation locale Z : +6 rad/s',
}


def tilt(row):
    """Angle between body up and world up, from Sputnik's YXZ Euler angles."""
    c = math.cos(math.radians(row['pitch'])) * math.cos(math.radians(row['roll']))
    return math.degrees(math.acos(max(-1, min(1, c))))


def stable(row):
    return (abs(row['y'] - row['target_y']) <= 1 and abs(row['vy']) <= .1
            and math.hypot(row['vx'], row['vz']) <= .2 and tilt(row) <= 5
            and row['active'] == 1)


def fresh(rows):
    return bool(rows) and all(b['universe_tick'] == a['universe_tick'] + 1
                             and b['tick'] == a['tick'] + 1
                             for a, b in zip(rows, rows[1:]))


def analyze(folder, case):
    with (folder / 'flight.csv').open() as source:
        rows = [{k: float(v) for k, v in r.items()} for r in csv.DictReader(source)]
    if not rows or not all(math.isfinite(v) for r in rows for v in r.values()):
        raise ValueError('Empty or non-finite physical trace')
    events = (folder / 'events.tsv').read_text()
    shock = re.search(r'^(\d+)\tSHOCK ' + re.escape(case) + r'\b.*$', events, re.M)
    if not shock:
        raise ValueError('No recorded physical impulse for ' + case)
    impulse_tick = int(shock.group(1))
    complete = re.search(r'^(\d+)\tCOMPLETE:', events, re.M)
    faults = list(re.finditer(r'^(\d+)\t(?:ABORT:|ERROR ).*$', events, re.M))
    # Samples at capture/OFF and exported cleanup pages never count as flight.
    stops = [int(m.group(1)) for m in faults]
    if complete:
        stops.append(int(complete.group(1)))
    end = min(stops) if stops else int(rows[-1]['tick']) + 1
    aborted = any(int(m.group(1)) <= end for m in faults)
    before = [r for r in rows if impulse_tick - 200 <= r['tick'] < impulse_tick]
    # ABORT is logged after that tick's physical observation, before capture.
    after = [r for r in rows if impulse_tick < r['tick'] < end
             or (aborted and r['tick'] == end)]
    if not after:
        raise ValueError('No free response after impulse')
    reference = next(r for r in rows if r['tick'] == impulse_tick)
    tail = after[-200:]
    baseline = len(before) == 200 and fresh(before) and all(stable(r) for r in before)
    settled = len(tail) == 200 and fresh(tail) and all(stable(r) for r in tail)
    protected = any(r['protection'] != 0 for r in after)
    protection_end = after[-1]['protection'] != 0
    target_preserved = all(abs(r['target_y'] - reference['target_y']) < 1e-6 for r in after)
    # A short quiet interval is distinct from sustained recovery to the end.
    streak = 0
    first20 = None
    previous = reference
    for row in after:
        streak = streak + 1 if stable(row) and fresh([previous, row]) else 0
        if streak >= 20 and first20 is None:
            first20 = (row['universe_tick'] - reference['universe_tick']) / 20
        previous = row
    suffix = 0
    previous = None
    for row in reversed(after):
        if not stable(row) or (previous is not None and not fresh([row, previous])):
            break
        suffix += 1
        previous = row
    sustained = ((after[-suffix]['universe_tick'] - reference['universe_tick']) / 20
                 if suffix >= 200 else None)
    displacement = lambda r: math.hypot(r['x'] - reference['x'], r['z'] - reference['z'])
    dt = lambda r: (r['universe_tick'] - reference['universe_tick']) / 20
    peak = max(after, key=tilt)
    delta_v = [after[0][k] - reference[k] for k in ('vx', 'vy', 'vz')]
    disturbance = (sum(v * v for v in delta_v) ** .5 > 1
                   if case in ('side5', 'side12', 'down8', 'up8', 'combined')
                   else any(tilt(r) > 5 for r in after[:20]))
    status = ('ABORT' if aborted else 'INVALID_BASELINE' if not baseline
              else 'FAIL' if not complete or not disturbance or not settled
              or not target_preserved or not fresh(after)
              else 'PROTECTED' if protection_end else 'PASS')
    return dict(
        case=case, label=LABELS[case], status=status,
        impulse_tick=impulse_tick, end_tick=end,
        impulse_event=shock.group(0), completed=bool(complete), aborted=aborted,
        baseline_200_fresh_stable=baseline, tail_200_fresh_stable=settled,
        target_preserved=target_preserved, horizontal_protection_observed=protected,
        disturbance_observed=disturbance,
        horizontal_protection_at_end=protection_end,
        fresh_tick_gaps=sum(not fresh([a, b]) for a, b in zip(after, after[1:])),
        free_response_seconds=dt(after[-1]), first_20_stable_seconds=first20,
        sustained_200_recovery_seconds=sustained,
        peak_height_error_m=max(abs(r['y'] - r['target_y']) for r in after),
        height_loss_m=max(0, reference['y'] - min(r['y'] for r in after)),
        peak_tilt_deg=tilt(peak), peak_tilt_tick=int(peak['tick']),
        peak_tilt_seconds=dt(peak), inverted_observed=any(tilt(r) > 90 for r in after),
        peak_vertical_speed_m_s=max(abs(r['vy']) for r in after),
        peak_horizontal_speed_m_s=max(math.hypot(r['vx'], r['vz']) for r in after),
        max_displacement_m=max(displacement(r) for r in after),
        final_displacement_m=displacement(after[-1]),
        tail_height_error_m=max(abs(r['y'] - r['target_y']) for r in tail),
        tail_vertical_speed_m_s=max(abs(r['vy']) for r in tail),
        tail_horizontal_speed_m_s=max(math.hypot(r['vx'], r['vz']) for r in tail),
        tail_tilt_deg=max(tilt(r) for r in tail),
        first_response_delta_v=delta_v,
        faults=[m.group(0) for m in faults],
    ), rows


def plot_case(pdf, output, result, rows):
    import matplotlib.pyplot as plt
    s = [r for r in rows if result['impulse_tick'] - 100 <= r['tick'] < result['end_tick']
         or (result['aborted'] and r['tick'] == result['end_tick'])]
    ref = next(r for r in rows if r['tick'] == result['impulse_tick'])
    t = [(r['universe_tick'] - ref['universe_tick']) / 20 for r in s]
    fig, axs = plt.subplots(3, 2, figsize=(12, 10))
    fig.suptitle(result['label'] + ' — ' + result['status'] + '\nMinecraft réel / Rapier — contrôleur Sputnik 0.4.1')
    axs[0, 0].plot(t, [r['y'] - r['target_y'] for r in s])
    axs[0, 0].axhspan(-1, 1, color='green', alpha=.1)
    axs[0, 0].set(title='Erreur d’altitude (cible conservée)', ylabel='m')
    axs[0, 1].plot(t, [tilt(r) for r in s], label='Inclinaison totale')
    axs[0, 1].axhline(90, color='red', ls=':', label='À l’envers au-delà')
    axs[0, 1].set(title='Assiette : angle verticale corps / monde', ylabel='degrés')
    axs[0, 1].legend(fontsize=8)
    axs[1, 0].plot(t, [r['vy'] for r in s], label='Verticale')
    axs[1, 0].plot(t, [math.hypot(r['vx'], r['vz']) for r in s], label='Horizontale')
    axs[1, 0].set(title='Vitesses observées', ylabel='m/s')
    axs[1, 0].legend()
    axs[1, 1].plot(t, [math.hypot(r['x'] - ref['x'], r['z'] - ref['z']) for r in s])
    axs[1, 1].set(title='Distance au point du choc (pas une cible de position)', ylabel='m')
    for i in range(1, 5):
        axs[2, 0].plot(t, [r['rpm' + str(i)] for r in s], label=str(i), lw=.8)
    axs[2, 0].set(title='Quatre régimes réels (valeurs absolues)', ylabel='RPM')
    axs[2, 0].legend(ncol=4)
    axs[2, 1].step(t, [r['protection'] for r in s], where='post')
    axs[2, 1].set(title='Protection horizontale du superviseur', ylabel='0 / 1', ylim=(-.1, 1.2))
    for ax in axs.flat:
        ax.set_xlabel('Temps depuis le choc (s de jeu, ticks / 20)')
        ax.axvline(0, color='black', ls='--', lw=.8)
        ax.grid(alpha=.25)
    fig.tight_layout(rect=(0, .04, 1, .94))
    fig.text(.04, .015, 'Monde copié ; rotors préchauffés ; spectateur sans contact. ABORT = capture du banc, jamais une récupération.', fontsize=8)
    fig.savefig(output / (result['case'] + '.png'), dpi=140)
    pdf.savefig(fig)
    plt.close(fig)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--runs', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    import matplotlib
    matplotlib.use('Agg')
    from matplotlib.backends.backend_pdf import PdfPages
    results = []
    with PdfPages(args.output / 'shocks.pdf', metadata={'CreationDate': None, 'ModDate': None}) as pdf:
        for case in LABELS:
            run = args.runs / case
            if not (run / 'fixture/flight.csv').exists():
                continue
            result, rows = analyze(run / 'fixture', case)
            for name in ('run.json', 'exit.json'):
                if (run / name).exists():
                    result[name.removesuffix('.json')] = json.loads((run / name).read_text())
            dest = args.output / case
            dest.mkdir(exist_ok=True)
            for name in ('flight.csv', 'events.tsv', 'hardware.tsv', 'geometry.txt', 'descriptors.txt'):
                src = run / 'fixture' / name
                if src.exists():
                    shutil.copy2(src, dest / name)
            result['trace_sha256'] = hashlib.sha256((dest / 'flight.csv').read_bytes()).hexdigest()
            (dest / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
            plot_case(pdf, args.output, result, rows)
            results.append(result)
        if results:
            import matplotlib.pyplot as plt
            fig, axs = plt.subplots(1, 3, figsize=(14, 5))
            names = [r['case'] for r in results]
            colors = [{'PASS': '#27844b', 'PROTECTED': '#c68b18'}.get(r['status'], '#bc3434') for r in results]
            for ax, key, title, unit in [
                    (axs[0], 'peak_height_error_m', 'Erreur altitude transitoire maximale', 'm (échelle logarithmique)'),
                    (axs[1], 'peak_tilt_deg', 'Inclinaison maximale', 'degrés'),
                    (axs[2], 'sustained_200_recovery_seconds', 'Début du maintien conservé jusqu’à la fin', 's de jeu')]:
                vals = [r[key] if r[key] is not None else 0 for r in results]
                ax.bar(names, vals, color=colors)
                for i, (r, value) in enumerate(zip(results, vals)):
                    ax.annotate('échec' if r[key] is None else f'{value:.2f}', (i, value),
                                xytext=(0, 4), textcoords='offset points', ha='center', fontsize=8)
                ax.set(title=title, ylabel=unit)
                ax.tick_params(axis='x', rotation=45)
                ax.grid(axis='y', alpha=.2)
            axs[0].set_yscale('log')
            axs[1].axhline(90, color='red', ls=':', lw=.8)
            fig.suptitle('Chocs dans Minecraft — Sputnik 0.4.1 — même quad, copie neuve par cas')
            fig.text(.04, .02, 'Vert : PASS au maintien final. Orange : stabilité avec protection horizontale. Rouge : échec / capture du banc. Les transitoires restent mesurés.', fontsize=9)
            fig.tight_layout(rect=(0, .06, 1, .94))
            fig.savefig(args.output / 'overview.png', dpi=150)
            pdf.savefig(fig)
            plt.close(fig)
    report = dict(schema=1, source='real Minecraft 1.21.1 / Sable-Rapier impulses',
                  controller_globally_qualified=False, cases=results)
    (args.output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
    for r in results:
        print(r['case'], r['status'], 'h=', round(r['peak_height_error_m'], 3),
              'tilt=', round(r['peak_tilt_deg'], 1), 'recovery=', r['sustained_200_recovery_seconds'])


if __name__ == '__main__':
    main()
