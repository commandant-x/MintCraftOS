#!/usr/bin/env python3
"""Measured speed of slime-foot quadruped; peaks do not imply stable locomotion."""
import argparse,csv,json,math
from pathlib import Path
from analyze_course_speed import analyze as speed
from analyze_balance import analyze as balance

def analyze(p):
 s=speed(p);b=balance(p)
 with (p/'stand.csv').open(newline='') as f:poses={int(r['tick']):r for r in csv.DictReader(f) if int(r['tick'])>=280}
 with (p/'wireless.csv').open(newline='') as f:wire=list(csv.DictReader(f))
 keys=[f'{l}_{a}_rpm' for l in ('front_left','front_right','rear_left','rear_right') for a in ('roll','hip','knee')]
 windows=[]
 for t in poses:
  if t+20 in poses:
   a,b0=poses[t],poses[t+20];dx=float(b0['x'])-float(a['x']);dz=float(b0['z'])-float(a['z']);windows.append((dz,math.hypot(dx,dz)))
 angle_file=p/'angles.csv'
 if angle_file.exists():
  with angle_file.open(newline='') as f:angle_rows=list(csv.DictReader(f))
  channels=[k for k in angle_rows[0] if k!='tick'];deltas=[]
  for a,b0 in zip(angle_rows,angle_rows[1:]):
   for k in channels:deltas.append(abs((float(b0[k])-float(a[k])+180)%360-180))
  s['max_recorded_target_angle_change_degrees_per_tick']=max(deltas,default=0)
  s['target_angle_note']='change in commanded swivel target, not measured physical joint angle'
 s.update({'target_blocks_per_second':10,'maximum_tilt_from_world_up_degrees':b['maximum_tilt_from_world_up_degrees'],'maximum_abs_yaw_change_degrees':b['max_abs_yaw_change_degrees'],'maximum_lateral_shift_blocks':max(abs(float(v['x'])-float(poses[min(poses)]['x'])) for v in poses.values()),'first_tick_all_foot_centers_beyond_first_strip':b['first_tick_all_foot_centers_beyond_first_strip'],'best_forward_blocks_in_one_game_second':max((x[0] for x in windows),default=None),'best_horizontal_blocks_in_one_game_second':max((x[1] for x in windows),default=None),'ticks_with_multiple_cogs_running':sum(sum(abs(float(r[k]))>.01 for k in keys)>1 for r in wire),'slime_feet_count':(p/'audit.txt').read_text().count('lower_slime=1'),'limitations':'one unladen robot, one run per setting on flat track with obstacles; fixture presses UI, no player, force sensors or robust course qualification; simulation seconds assume 20 ticks/s'})
 return s
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('directory',type=Path);print(json.dumps(analyze(a.parse_args().directory),indent=2))
