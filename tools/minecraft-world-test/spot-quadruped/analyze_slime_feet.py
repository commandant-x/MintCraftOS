#!/usr/bin/env python3
"""Summarize matched quadruped foot-material trials; no friction coefficient is inferred."""
import argparse,csv,json,math,re
from pathlib import Path
from analyze_balance import analyze as balance

def analyze(p):
 result=balance(p)
 with (p/'stand.csv').open(newline='') as f:poses={int(r['tick']):r for r in csv.DictReader(f)}
 with (p/'wireless.csv').open(newline='') as f:wire=list(csv.DictReader(f))
 keys=[f'{l}_{a}_rpm' for l in ('front_left','front_right','rear_left','rear_right') for a in ('roll','hip','knee')]
 result['ticks_with_multiple_cogs_running']=sum(sum(abs(float(r[k]))>.01 for k in keys)>1 for r in wire)
 result['final_feet_z']={leg:float(poses[max(poses)][leg+'_foot_z']) for leg in ('front_left','front_right','rear_left','rear_right')}
 if result['perturbation']:
  t=result['perturbation']['tick'];pre=poses[t-1];stop=min(t+200,max(poses));window=[poses[k] for k in range(t,stop+1) if k in poses];result['perturbation']['maximum_absolute_lateral_shift_next_200_ticks_blocks']=max(abs(float(r['x'])-float(pre['x'])) for r in window)
  after=poses[stop];result['perturbation']['foot_center_horizontal_change_after_200_ticks']={leg:math.hypot(float(after[leg+'_foot_x'])-float(pre[leg+'_foot_x']),float(after[leg+'_foot_z'])-float(pre[leg+'_foot_z'])) for leg in ('front_left','front_right','rear_left','rear_right')}
 audit=(p/'audit.txt').read_text();result['slime_feet_count']=len(re.findall(r'lower_slime=1\b',audit));result['wood_feet_count']=len(re.findall(r'lower_slime=0\b',audit))
 result['limitations']='one trial per material and scenario; positions do not measure contact forces, slipperiness coefficient or general adhesion; reload, settling and solver variation may influence the result'
 return result
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('directory',type=Path);print(json.dumps(analyze(a.parse_args().directory),indent=2))
