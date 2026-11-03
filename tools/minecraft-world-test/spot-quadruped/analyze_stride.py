#!/usr/bin/env python3
"""Analyze measured lane feedback, actuator pulses and robot motion."""
import argparse,csv,itertools,json,math
from pathlib import Path
from analyze_slime_speed import analyze as speed

def analyze(p):
 result=speed(p)
 with (p/'telemetry.csv').open(newline='') as f:t=list(csv.DictReader(f))
 with (p/'wireless.csv').open(newline='') as f:w=list(csv.DictReader(f))
 values=lambda key:[float(r[key]) for r in t if r.get(key) not in (None,'missing','')]
 lane=values('lane_error');steer=values('steering_error');valid=values('pose_valid');guard=values('tilt_guard')
 pulses={}
 for leg in ('front_left','front_right','rear_left','rear_right'):
  for axis in ('hip','knee'):
   key=leg+'_'+axis;groups=[len(list(g)) for on,g in itertools.groupby(w,key=lambda r:int(r[key+'_signal'])==0) if on];paired=len(groups)//2
   pulses[key]={'pulse_groups':len(groups),'complete_pairs':paired,'unequal_pairs':sum(groups[2*i]!=groups[2*i+1] for i in range(paired)),'last_unpaired_group':groups[-1] if len(groups)%2 else None}
 result.update({'lane_error_range_blocks':[min(lane),max(lane)] if lane else None,'steering_error_range_degrees':[min(steer),max(steer)] if steer else None,'telemetry_pose_valid_all':all(x>0.5 for x in valid) if valid else None,'telemetry_guard_tripped':any(x>0.5 for x in guard) if guard else None,'pulse_pairs':pulses,'limitations':'one run per candidate on same saved world; settling may vary; lane error is measured at the Sputnik block and not foot contact; no player, variable load, or completed obstacle qualification'})
 return result
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('directory',type=Path);print(json.dumps(analyze(a.parse_args().directory),indent=2))
