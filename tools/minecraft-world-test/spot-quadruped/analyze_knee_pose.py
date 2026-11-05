#!/usr/bin/env python3
"""Measure knee relative rotation against the first recorded physical pose."""
import csv
import json
import math
import sys
from pathlib import Path

root = Path(sys.argv[1])
with (root / 'drive.csv').open(newline='') as source:
    rows = list(csv.DictReader(source))
if not rows:
    raise ValueError('drive.csv has no recorded poses')

def qnorm(q):
    n = math.sqrt(sum(v*v for v in q))
    if not math.isfinite(n) or n < 1e-12:
        raise ValueError('Invalid quaternion')
    return tuple(v/n for v in q)

def inv(q):
    x,y,z,w = qnorm(q)
    return (-x,-y,-z,w)

def mul(a,b):
    x,y,z,w=a; X,Y,Z,W=b
    return (w*X+x*W+y*Z-z*Y, w*Y-x*Z+y*W+z*X,
            w*Z+x*Y-y*X+z*W, w*W-x*X-y*Y-z*Z)

def joint(row,leg):
    hip = tuple(float(row[f'{leg}_hip_q{k}']) for k in 'xyzw')
    knee = tuple(float(row[f'{leg}_knee_q{k}']) for k in 'xyzw')
    return qnorm(mul(inv(hip),qnorm(knee)))

legs = ('front_left','front_right','rear_left','rear_right')
baseline = {leg:joint(rows[0],leg) for leg in legs}
poses = []
for row in rows:
    angles = {}
    for leg in legs:
        delta = qnorm(mul(inv(baseline[leg]),joint(row,leg)))
        angles[leg] = {'relative_change_degrees':math.degrees(2*math.acos(min(1.0,abs(delta[3])))),
                       'target_degrees':float(row[f'{leg}_knee_target'])}
    poses.append({'tick':int(row['tick']), 'phase':row['phase'], 'knees':angles})
print(json.dumps({'reference':rows[0]['phase'], 'poses':poses,
                  'note':'Physical relative orientation change; unsigned angle, not contact, torque or biomechanical range.'},indent=2))
