#!/usr/bin/env python3
"""Summarize each impulse and observed joint motion in a recorded push series."""
import csv
import json
import math
import re
import sys
from pathlib import Path

root=Path(sys.argv[1])
with (root/'events.tsv').open() as f:
    events=list(csv.DictReader(f,delimiter='\t'))
with (root/'stand.csv').open(newline='') as f:
    stand=list(csv.DictReader(f))
with (root/'wireless.csv').open(newline='') as f:
    wireless=list(csv.DictReader(f))
with (root/'telemetry.csv').open(newline='') as f:
    telemetry=list(csv.DictReader(f))
impulses=[(int(e['tick']),e['event']) for e in events if e['event'].startswith('IMPULSE ')]
if not impulses:
    raise ValueError('No impulse events recorded')
def tilt(row):
    return math.degrees(math.acos(max(-1,min(1,1-2*(float(row['qx'])**2+float(row['qz'])**2)))))
def active(row):
    return any(abs(float(value))>.01 for key,value in row.items() if key.endswith('_rpm') and not key.endswith('_axial_rpm') and key!='motor_rpm')
results=[]
for index,(start,event) in enumerate(impulses):
    end=impulses[index+1][0] if index+1<len(impulses) else int(stand[-1]['tick'])+1
    poses=[x for x in stand if start<=int(x['tick'])<end]
    motor=[x for x in wireless if start<=int(x['tick'])<end]
    t=[x for x in telemetry if start<=int(x['tick'])<end]
    if not poses:
        raise ValueError(f'Missing pose for impulse tick {start}')
    a,b=poses[0],poses[-1]
    results.append({'tick':start,'impulse':event,
                    'max_tilt_degrees':max(map(tilt,poses)),
                    'final_tilt_degrees':tilt(b),
                    'height_change':float(b['y'])-float(a['y']),
                    'horizontal_distance':math.hypot(float(b['x'])-float(a['x']),float(b['z'])-float(a['z'])),
                    'active_joint_ticks':sum(active(x) for x in motor),
                    'extension_command_ticks':sum(x.get('correction_axis')=='3.0' for x in t),
                    'rebend_command_ticks':sum(x.get('correction_axis')=='6.0' for x in t)})
print(json.dumps({'impulses':results,'completed':(root/'complete.txt').exists(),
                  'fixture_error':(root/'error.txt').read_text().strip() if (root/'error.txt').exists() else None,
                  'note':'No contact or force feedback; window distances include all body motion, including sliding.'},indent=2))
