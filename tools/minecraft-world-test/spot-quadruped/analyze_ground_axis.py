#!/usr/bin/env python3
"""Extract isolated on-ground pulse responses from one instrumented Minecraft trial."""
import csv
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
with (root / 'wireless.csv').open(newline='') as f:
    wireless = list(csv.DictReader(f))
with (root / 'telemetry.csv').open(newline='') as f:
    telemetry = {int(row['tick']): row for row in csv.DictReader(f)}
result = []
for key in wireless[0]:
    if not key.endswith('_rpm') or key.endswith('_axial_rpm') or key == 'motor_rpm':
        continue
    previous = 0.0
    for row in wireless:
        speed = float(row[key])
        tick = int(row['tick'])
        if abs(speed) > .01 and abs(previous) <= .01 and tick - 1 in telemetry and tick + 10 in telemetry:
            start, end = telemetry[tick - 1], telemetry[tick + 10]
            result.append({'axis': key[:-4], 'tick': tick, 'rpm': speed,
                           'reverse_signal': int(row[key[:-4] + '_reverse']),
                           'pitch_change': float(end['pitch_error']) - float(start['pitch_error']),
                           'roll_change': float(end['roll_error']) - float(start['roll_error']),
                           'drop_change': float(end['drop']) - float(start['drop'])})
        previous = speed
print(json.dumps({'description': 'Ten-tick body-angle change after isolated grounded pulse; one trial, not a force or contact measurement.',
                  'samples': result}, indent=2))
