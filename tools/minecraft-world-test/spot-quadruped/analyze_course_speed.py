#!/usr/bin/env python3
"""Measure course speed per simulation tick at nominal 20 ticks/second."""
import argparse,csv,json,math
from pathlib import Path
from analyze_course import analyze as summarize

def analyze(p):
 result=summarize(p)
 with (p/'stand.csv').open(newline='') as f:rows=list(csv.DictReader(f))
 rows=[r for r in rows if int(r['tick'])>=280]
 if len(rows)<2:raise ValueError('insufficient motion data')
 first,last=rows[0],rows[-1];dt=int(last['tick'])-int(first['tick']);dx=float(last['x'])-float(first['x']);dz=float(last['z'])-float(first['z'])
 speeds=[]
 for a,b in zip(rows,rows[1:]):
  n=int(b['tick'])-int(a['tick'])
  if n>0:speeds.append(20*math.hypot(float(b['x'])-float(a['x']),float(b['z'])-float(a['z']))/n)
 result.update({'motor_rpm':float(next(csv.DictReader((p/'wireless.csv').open()))['motor_rpm']),'elapsed_game_ticks':dt,'nominal_game_seconds':dt/20,'mean_forward_blocks_per_game_second':dz*20/dt,'mean_horizontal_blocks_per_game_second':math.hypot(dx,dz)*20/dt,'peak_single_tick_horizontal_blocks_per_game_second':max(speeds),'target_blocks_per_second':25,'speed_at_nominal_20_tps':True,'speed_note':'single-tick peak includes vibration or slip; not sustained speed, real-time speed varies with server tick rate'})
 return result
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('directory',type=Path);print(json.dumps(analyze(a.parse_args().directory),indent=2))
