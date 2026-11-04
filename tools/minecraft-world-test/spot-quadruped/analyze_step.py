#!/usr/bin/env python3
"""Analyze one attempted leg lift and placement on a free quadruped."""
import argparse,csv,json,math
from pathlib import Path
LEGS=('front_left','front_right','rear_left','rear_right')
def analyze(p):
 with (p/'stand.csv').open(newline='') as f:rows={int(r['tick']):r for r in csv.DictReader(f)}
 if sorted(rows)!=[280]+list(range(290,601,10)):raise ValueError('incomplete step trace')
 if rows[280]['chassis_locked']!='true' or any(rows[t]['chassis_locked']!='false' for t in range(290,601,10)):raise ValueError('unexpected chassis lock state')
 if any(r[leg+'_'+axis+'_locked']!='false' for r in rows.values() for leg in LEGS for axis in ('roll','hip','knee')):raise ValueError('one or more leg bodies remain staff-locked')
 def orient(r):
  v=[float(r[k]) for k in ('qx','qy','qz','qw')];n=math.sqrt(sum(x*x for x in v))
  if not math.isfinite(n) or abs(n-1)>.01:raise ValueError('invalid quaternion')
  return [x/n for x in v]
 baseline=rows[330];x0,y0,z0=(float(baseline[k]) for k in ('x','y','z'));q0=orient(baseline);foot0=float(baseline['rear_left_foot_y']);run=[rows[t] for t in range(340,601,10)]
 tilt=[math.degrees(2*math.acos(min(1,abs(sum(a*b for a,b in zip(q0,orient(r))))))) for r in run]
 height=[float(r['rear_left_foot_y']) for r in run];last=rows[600]
 commands={str(t):{'knee_rpm':float(rows[t]['test_knee_rpm']),'knee_target':float(rows[t]['test_knee_target']),'hip_rpm':float(rows[t]['test_hip_rpm']),'hip_target':float(rows[t]['test_hip_target'])} for t in (330,350,360,370,380,400,410,420,430,440,460)}
 return {'single_leg':'rear_left','test':'one bend, hip movement, straighten and return under redstone; no repeated gait','foot_center_initial_y':foot0,'foot_center_max_y':max(height),'foot_center_peak_lift_blocks':max(height)-foot0,'foot_center_final_y':float(last['rear_left_foot_y']),'body_displacement_x_blocks':float(last['x'])-x0,'body_displacement_y_blocks':float(last['y'])-y0,'body_displacement_z_blocks':float(last['z'])-z0,'maximum_orientation_change_degrees':max(tilt),'callbacks_per_foot_after_baseline':{leg:int(last[leg+'_contacts'])-int(baseline[leg+'_contacts']) for leg in LEGS},'commands':commands,'all_thirteen_bodies_staff_unlocked_after_release':True,'test_guide_present':False,'repeated_walking_tested':False,'limitations':'one scripted test-only redstone cycle; no Sputnik, player, contact force measurement or repeated gait'}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('directory',type=Path);print(json.dumps(analyze(p.parse_args().directory),indent=2))
