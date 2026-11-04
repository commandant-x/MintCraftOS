#!/usr/bin/env python3
"""Evaluate unassisted quadruped standing and four instrumented foot contacts."""
import argparse,csv,json,math
from pathlib import Path
LEGS=('front_left','front_right','rear_left','rear_right')
def analyze(p):
 with (p/'stand.csv').open(newline='') as f:rows=list(csv.DictReader(f))
 if [int(r['tick']) for r in rows]!=[280]+list(range(290,501,10)):raise ValueError('incomplete standing trace')
 if rows[0]['chassis_locked']!='true' or any(r['chassis_locked']!='false' for r in rows[1:]):raise ValueError('unexpected chassis lock state')
 if any(r[leg+'_'+axis+'_locked']!='false' for r in rows for leg in LEGS for axis in ('roll','hip','knee')):raise ValueError('one or more leg bodies remain staff-locked')
 if any(abs(float(r['motor_rpm']))>.001 for r in rows):raise ValueError('motor did not remain stopped')
 def orient(r):
  v=[float(r[k]) for k in ('qx','qy','qz','qw')];n=math.sqrt(sum(x*x for x in v))
  if not math.isfinite(n) or abs(n-1)>.01:raise ValueError('invalid chassis orientation')
  return [x/n for x in v]
 x0,y0,z0=(float(rows[0][k]) for k in ('x','y','z'));q0=orient(rows[0]);samples=[]
 for r in rows[1:]:
  x,y,z=(float(r[k]) for k in ('x','y','z'));q=orient(r);d=abs(sum(a*b for a,b in zip(q0,q)))
  samples.append({'tick':int(r['tick']),'drop_blocks':y0-y,'horizontal_blocks':math.hypot(x-x0,z-z0),'rotation_degrees':math.degrees(2*math.acos(min(1,d)))})
 foot={}
 for leg in LEGS:
  counts=[int(r[leg+'_contacts']) for r in rows]
  if any(b<a for a,b in zip(counts,counts[1:])):raise ValueError('nonmonotonic contact counter')
  foot[leg]={'callbacks_before_release':counts[0],'callbacks_after_release':counts[-1]-counts[0],'foot_y_final':float(rows[-1][leg+'_foot_y'])}
 md=max(abs(r['drop_blocks']) for r in samples);mh=max(r['horizontal_blocks'] for r in samples);mr=max(r['rotation_degrees'] for r in samples)
 return {'sample_ticks':len(samples),'duration_game_ticks':int(rows[-1]['tick'])-int(rows[0]['tick']),'motor_rpm':0,'all_twelve_leg_bodies_staff_unlocked':True,'chassis_staff_unlocked_after_initial_sample':True,'test_guide_present':False,'floor':'instrumented full blocks with Sable contact callback','feet':foot,'all_four_foot_callbacks_after_release':all(v['callbacks_after_release']>0 for v in foot.values()),'max_absolute_vertical_displacement_blocks':md,'max_horizontal_displacement_blocks':mh,'max_orientation_change_degrees':mr,'within_test_tolerance':md<.1 and mh<.1 and mr<1,'walking_tested':False,'limitations':'static standing only; callback counts do not measure loads, and no player or gait tested'}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('directory',type=Path);print(json.dumps(analyze(p.parse_args().directory),indent=2))
