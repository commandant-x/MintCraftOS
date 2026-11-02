#!/usr/bin/env python3
"""Report an eight-cycle quadruped gait experiment without assuming success."""
import argparse,csv,json,math
from pathlib import Path
LEGS=('front_left','front_right','rear_left','rear_right');ORDER=('front_left','rear_right','front_right','rear_left')
def analyze(path):
 with (path/'stand.csv').open(newline='') as f:rows={int(r['tick']):r for r in csv.DictReader(f)}
 if sorted(rows)!=[280]+list(range(290,1501,10)):raise ValueError('incomplete gait trace')
 if rows[280]['chassis_locked']!='true' or any(rows[t]['chassis_locked']!='false' for t in range(290,1501,10)):raise ValueError('unexpected chassis lock state')
 if any(r[leg+'_'+axis+'_locked']!='false' for r in rows.values() for leg in LEGS for axis in ('roll','hip','knee')):raise ValueError('one or more leg bodies remain staff-locked')
 def orient(r):
  v=[float(r[k]) for k in ('qx','qy','qz','qw')];n=math.sqrt(sum(x*x for x in v))
  if not math.isfinite(n) or abs(n-1)>.01:raise ValueError('invalid orientation')
  return [x/n for x in v]
 base=rows[330];x0,y0,z0=(float(base[k]) for k in ('x','y','z'));q0=orient(base);run=[rows[t] for t in range(340,1501,10)];last=rows[1500]
 tilts=[math.degrees(2*math.acos(min(1,abs(sum(a*b for a,b in zip(q0,orient(r))))))) for r in run];max_tilt=max(tilts)
 first_fall=next((int(r['tick']) for r,a in zip(run,tilts) if a>30 or y0-float(r['y'])>2),None)
 max_drop=max(y0-float(r['y']) for r in run);path_length=sum(math.hypot(float(b['x'])-float(a['x']),float(b['z'])-float(a['z'])) for a,b in zip([base]+run,run))
 cycles=[]
 for n in range(8):
  start=340+n*130;leg=ORDER[n%4];before=rows[start];window=[rows[t] for t in range(start,start+121,10)];initial=float(before[leg+'_foot_y']);peak=max(float(r[leg+'_foot_y']) for r in window)
  knee=float(rows[start+20]['test_knee_rpm']);hip=float(rows[start+40]['test_hip_rpm']);reverse_knee=float(rows[start+70]['test_knee_rpm'])
  cycles.append({'index':n,'leg':leg,'started_after_observed_fall':first_fall is not None and start>=first_fall,'fall_during_cycle':first_fall is not None and start<=first_fall<start+130,'foot_center_peak_lift_blocks':peak-initial,'knee_forward_rpm':knee,'hip_forward_rpm':hip,'knee_reverse_rpm':reverse_knee,'selected_knee_reversed':abs(knee)>.01 and knee*reverse_knee<0,'foot_callbacks_increase':int(window[-1][leg+'_contacts'])-int(before[leg+'_contacts'])})
 return {'first_observed_fall_tick':first_fall,'cycles':cycles,'all_eight_knee_direction_reversals_observed':all(c['selected_knee_reversed'] for c in cycles),'body_displacement_x_blocks':float(last['x'])-x0,'body_displacement_y_blocks':float(last['y'])-y0,'body_displacement_z_blocks':float(last['z'])-z0,'horizontal_net_displacement_blocks':math.hypot(float(last['x'])-x0,float(last['z'])-z0),'horizontal_sampled_path_length_blocks':path_length,'max_orientation_change_degrees':max_tilt,'max_vertical_drop_blocks':max_drop,'motor_final_rpm':float(last['motor_rpm']),'all_thirteen_bodies_staff_unlocked_after_release':True,'test_guide_present':False,'limitations':'eight scripted leg cycles using test-only redstone blocks; no Sputnik controller, no player, no contact force measurement and no claim of robust gait'}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('directory',type=Path);print(json.dumps(analyze(p.parse_args().directory),indent=2))
