#!/usr/bin/env python3
"""Analyze measured quadruped progress and sampled poses on the 250-block course."""
import argparse,csv,json,math,re
from pathlib import Path

def analyze(p):
 with (p/'stand.csv').open(newline='') as f:rows=list(csv.DictReader(f))
 if len(rows)<2:raise ValueError('insufficient samples')
 base=rows[0];q0=[float(base[k]) for k in ('qx','qy','qz','qw')];qnorm=math.sqrt(sum(v*v for v in q0));q0=[v/qnorm for v in q0]
 def angle(r):
  q=[float(r[k]) for k in ('qx','qy','qz','qw')];norm=math.sqrt(sum(v*v for v in q));return math.degrees(2*math.acos(min(1,abs(sum(a*b for a,b in zip(q0,q))/norm))))
 progress=[float(r['z'])-float(base['z']) for r in rows];last=rows[-1];state=(p/'result.txt').read_text().strip();feet=('front_left','front_right','rear_left','rear_right')
 encounters={}
 for z in (64,82,112,152,202,252,286):
  encountered=next((int(r['tick']) for r in rows if max(float(r[f+'_foot_z']) for f in feet)>=z),None)
  encounters[str(z)]={'first_sample_foot_reaching_strip_z':encountered,'note':'longitudinal foot position only, does not prove contact or crossing'}
 return {'result':state,'samples':len(rows),'start_z':float(base['z']),'last_z':float(last['z']),'net_progress_z_blocks':progress[-1],'maximum_progress_z_blocks':max(progress),'target_progress_blocks':250,'lateral_displacement_blocks':float(last['x'])-float(base['x']),'maximum_orientation_change_degrees':max(map(angle,rows)),'maximum_vertical_drop_blocks':max(float(base['y'])-float(r['y']) for r in rows),'feet_reaching_obstacle_z':encounters,'limitations':'sampled every 10 ticks; no obstacle contact-force sensing, player, terrain feedback, or independent steering'}
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('directory',type=Path);print(json.dumps(analyze(a.parse_args().directory),indent=2))
