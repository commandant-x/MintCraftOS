#!/usr/bin/env python3
"""Summarize an isolated impulse; no inference of contact or controller success."""
import csv
import json
import math
import sys
from pathlib import Path

root = Path(sys.argv[1])
push_tick = int(sys.argv[2]) if len(sys.argv) > 2 else 500
with (root / 'stand.csv').open(newline='') as source:
    all_rows = list(csv.DictReader(source))
rows = [row for row in all_rows if int(row['tick']) >= push_tick]
if not rows or int(rows[0]['tick']) != push_tick:
    raise ValueError(f'No recorded push baseline at tick {push_tick}')
def tilt(row):
    return math.degrees(math.acos(max(-1.0, min(1.0, 1.0 - 2.0 * (float(row['qx'])**2 + float(row['qz'])**2)))))
initial, final = rows[0], rows[-1]
dx = float(final['x']) - float(initial['x'])
dz = float(final['z']) - float(initial['z'])
active = 0
with (root / 'wireless.csv').open(newline='') as source:
    for row in csv.DictReader(source):
        if int(row['tick']) >= push_tick and any(abs(float(value)) > .01 for key, value in row.items() if key.endswith('_rpm') and not key.endswith('_axial_rpm') and key != 'motor_rpm'):
            active += 1
print(json.dumps({'initial_tick': push_tick, 'final_tick': int(final['tick']),
                  'final_dx': dx, 'final_dz': dz, 'final_horizontal_distance': math.hypot(dx, dz),
                  'final_height_change': float(final['y']) - float(initial['y']),
                  'maximum_tilt_degrees': max(map(tilt, rows)), 'final_tilt_degrees': tilt(final),
                  'ticks_with_measured_joint_rpm': active,
                  'complete_marker': (root / 'complete.txt').exists(),
                  'fixture_error': (root / 'error.txt').read_text().strip() if (root / 'error.txt').exists() else None,
                  'note': 'A complete marker means the protocol ended, not that recovery succeeded. No contact or force measured.'}, indent=2))
