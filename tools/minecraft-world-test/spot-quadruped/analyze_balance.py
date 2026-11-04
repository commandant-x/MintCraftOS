#!/usr/bin/env python3
"""Analyze robot pose, yaw telemetry and perturbation on the actual course."""
import argparse,csv,json,math,re
from pathlib import Path

def rows(p):
 with p.open(newline='') as f:return list(csv.DictReader(f))
def analyze(p):
 positions=rows(p/'stand.csv');telemetry=rows(p/'telemetry.csv');by_tick={int(r['tick']):r for r in positions};initial=positions[0]
 def yaw(r):
  x,y,z,w=(float(r[k]) for k in ('qx','qy','qz','qw'));return math.degrees(math.atan2(2*(w*y+x*z),1-2*(y*y+x*x)))
 def upangle(r):
  x,y,z,w=(float(r[k]) for k in ('qx','qy','qz','qw'));return math.degrees(math.acos(max(-1,min(1,1-2*(x*x+z*z)))))
 def wrapped(a,b):return (a-b+180)%360-180
 errors=[];feedback=[]
 for t in telemetry:
  p0=by_tick.get(int(t['tick']))
  if p0 is not None and t['yaw'] not in ('missing','-9999'):
   errors.append(abs(wrapped(float(t['yaw']),yaw(p0))))
  if 'yaw_error' in t and t['yaw_error'] not in ('missing','-9999'):feedback.append(float(t['yaw_error']))
 feet=('front_left','front_right','rear_left','rear_right');all_cross=next((int(r['tick']) for r in positions if all(float(r[f+'_foot_z'])>65 for f in feet)),None)
 event=(p/'events.tsv').read_text();m=re.search(r'^(\d+)\tApplied one lateral chassis impulse: nominal delta_v=([^ ]+) chassis_mass=([^\n]+)',event,re.M)
 perturb=None
 if m:
  t=int(m.group(1));pre=by_tick[t-1];after=by_tick[max(by_tick)];later=by_tick.get(t+200,after);perturb={'tick':t,'nominal_chassis_delta_v':float(m.group(2)),'chassis_mass':float(m.group(3)),'impulse_description':'one chassis impulse J = chassis mass * nominal delta-v, no applied torque','tilt_before_degrees':upangle(pre),'maximum_tilt_next_200_ticks_degrees':max(upangle(r) for r in positions if t<=int(r['tick'])<=min(t+200,max(by_tick))),'tilt_after_200_ticks_degrees':upangle(later),'lateral_shift_after_200_ticks_blocks':float(later['x'])-float(pre['x'])}
 angular=None
 am=re.search(r'^(\d+)\tApplied one angular-velocity disturbance: delta_omega_z=([^ ]+) rad/s',event,re.M)
 if am:
  at=int(am.group(1));end=min(at+200,max(by_tick));pre=by_tick[at-1];last_after=by_tick[end];angular={'tick':at,'added_angular_velocity_z_rad_per_s':float(am.group(2)),'peak_tilt_next_200_ticks_degrees':max(upangle(r) for r in positions if at<=int(r['tick'])<=end),'tilt_after_200_ticks_degrees':upangle(last_after),'tilt_before_degrees':upangle(pre)}
  if perturb:
   pre=by_tick[perturb['tick']-1];perturb['maximum_absolute_lateral_shift_before_angular_test_blocks']=max(abs(float(r['x'])-float(pre['x'])) for r in positions if perturb['tick']<=int(r['tick'])<at)
 last=positions[-1];return {'angular_perturbation':angular,'result':(p/'result.txt').read_text().strip(),'samples':len(positions),'net_forward_blocks':float(last['z'])-float(initial['z']),'net_lateral_blocks':float(last['x'])-float(initial['x']),'maximum_tilt_from_world_up_degrees':max(map(upangle,positions)),'maximum_vertical_drop_blocks':max(float(initial['y'])-float(r['y']) for r in positions),'max_abs_yaw_change_degrees':max(abs(wrapped(yaw(r),yaw(initial))) for r in positions),'telemetry_samples':len(telemetry),'max_sputnik_vs_physics_yaw_error_degrees':max(errors) if errors else None,'feedback_yaw_error_range_degrees':[min(feedback),max(feedback)] if feedback else None,'first_tick_all_foot_centers_beyond_first_strip':all_cross,'perturbation':perturb,'limitations':'physical pose sampled per tick, Sputnik outputs every ten ticks; foot center is not a contact-force measurement; single copy, no player or variable load'}
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('directory',type=Path);print(json.dumps(analyze(a.parse_args().directory),indent=2))
