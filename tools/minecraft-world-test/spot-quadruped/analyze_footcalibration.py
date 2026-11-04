#!/usr/bin/env python3
"""Measure foot movement from the recorded locked-chassis 128 RPM calibration."""
import csv
import json
import math
import sys
from pathlib import Path

root = Path(sys.argv[1])
with (root / 'stand.csv').open(newline='') as f:
    rows = {int(row['tick']): row for row in csv.DictReader(f)}
with (root / 'drive.csv').open(newline='') as f:
    drive = {(int(row['case']), row['phase']): row for row in csv.DictReader(f)}
result = []
for case in range(12):
    leg = ('fl', 'fr', 'rl', 'rr')[case // 3]
    long_leg = ('front_left', 'front_right', 'rear_left', 'rear_right')[case // 3]
    axis = ('roll', 'hip', 'knee')[case % 3]
    tick = 290 + case * 28
    a, b, c = (rows[tick + offset] for offset in (0, 8, 20))
    keys = [f'{leg}_{coordinate}' for coordinate in 'xyz']
    forward = [float(b[k]) - float(a[k]) for k in keys]
    reverse = [float(c[k]) - float(b[k]) for k in keys]
    rpm_key = f'{long_leg}_{axis}_rpm'
    fwd_rpm = float(drive[(case, 'forward')][rpm_key])
    rev_rpm = float(drive[(case, 'reverse')][rpm_key])
    if abs(abs(fwd_rpm) - 64) > 0.01 or abs(fwd_rpm + rev_rpm) > 0.01:
        raise ValueError(f'Unexpected observed speed on {long_leg} {axis}')
    result.append({'leg': long_leg, 'axis': axis, 'forward_rpm': fwd_rpm,
                   'forward_displacement_xyz': forward,
                   'forward_displacement_norm': math.sqrt(sum(v*v for v in forward)),
                   'reverse_rpm': rev_rpm, 'reverse_displacement_xyz': reverse})
print(json.dumps({'context': 'locked chassis, no ground contact; four-tick selection followed by four ticks',
                  'axes': result}, indent=2))
