#!/usr/bin/env python3
"""Report the free chassis motion in the single-leg ground test."""
import argparse,csv,json,math
from pathlib import Path
from analyze_ground import analyze as ground

def analyze(path):
 with (path/'chassis.csv').open(newline='') as f: rows=list(csv.DictReader(f))
 if [int(r['tick']) for r in rows]!=[230]+list(range(240,681,10)):raise ValueError('incomplete chassis trace')
 if rows[0]['locked']!='true' or any(r['locked']!='false' for r in rows[1:]):raise ValueError('unexpected support locks')
 def p(r):return [float(r[k]) for k in ('x','y','z')]
 def q(r):
  v=[float(r[k]) for k in ('qx','qy','qz','qw')];norm=math.sqrt(sum(x*x for x in v))
  if not math.isfinite(norm) or abs(norm-1)>.01:raise ValueError('invalid orientation')
  return [x/norm for x in v]
 p0=p(rows[0]);q0=q(rows[0]);records=[]
 for r in rows[1:]:
  pp=p(r);qq=q(r);horizontal=math.hypot(pp[0]-p0[0],pp[2]-p0[2]);drop=p0[1]-pp[1];tilt=math.degrees(2*math.acos(min(1,abs(sum(a*b for a,b in zip(q0,qq))))))
  records.append({'tick':int(r['tick']),'horizontal_displacement_blocks':horizontal,'vertical_drop_blocks':drop,'orientation_change_degrees':tilt})
 early=next(r for r in records if r['tick']==260);first_large_tilt=next((r['tick'] for r in records if r['orientation_change_degrees']>45),None)
 return {'initial_chassis_position':p0,'at_first_axis_command':early,'maximum_horizontal_displacement_blocks':max(r['horizontal_displacement_blocks'] for r in records),'maximum_vertical_drop_blocks':max(r['vertical_drop_blocks'] for r in records),'maximum_orientation_change_degrees':max(r['orientation_change_degrees'] for r in records),'first_orientation_change_over_45_deg_tick':first_large_tilt,'final':records[-1],'ground':ground(path,free_chassis=True),'free_chassis_remained_upright':False if first_large_tilt is not None else None,'walking_tested':False,'limitations':'one free test chassis and one leg; no active balance controller or robot body'}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('directory',type=Path);print(json.dumps(analyze(p.parse_args().directory),indent=2))
