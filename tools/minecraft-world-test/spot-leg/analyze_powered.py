#!/usr/bin/env python3
"""Analyze a single motor-driven hip-roll trial and its recorded poses."""
import argparse,csv,json,math
from pathlib import Path

def analyze(directory):
 with (directory/'poses.csv').open(newline='') as f: poses=list(csv.DictReader(f))
 with (directory/'drive.csv').open(newline='') as f: drive=list(csv.DictReader(f))
 if [int(r['tick']) for r in poses]!=[230]+list(range(240,361,10)): raise ValueError('incomplete pose samples')
 if [int(r['tick']) for r in drive]!=list(range(240,361,10)): raise ValueError('incomplete drive samples')
 if poses[0]['phase']!='before_drive' or any(r['phase']!='after_drive' for r in poses[1:]): raise ValueError('wrong test phase')
 if any(poses[0][part+'_locked']!='true' for part in ('knee','hip_pitch','hip_roll')): raise ValueError('not initially locked')
 if any(r[part+'_locked']!='false' for r in poses[1:] for part in ('knee','hip_pitch','hip_roll')): raise ValueError('not released')
 if not all(float(r['motor_rpm'])==4 and float(r['cog_rpm'])==-4 for r in drive[:2]): raise ValueError('no observed cog drive')
 if not all(float(r['motor_rpm'])==0 and float(r['cog_rpm'])==0 for r in drive[2:]): raise ValueError('motor did not stop')
 def q(r):
  v=[float(r['hip_roll_q'+c]) for c in 'xyzw']; norm=math.sqrt(sum(n*n for n in v))
  if not math.isfinite(norm) or abs(norm-1)>.01:raise ValueError('bad orientation')
  return [n/norm for n in v]
 x0,y0,z0,w0=q(poses[0]);angles=[]
 for r in poses[1:]:
  x,y,z,w=q(r);dz=-w*z0-x*y0+y*x0+z*w0;dw=w*w0+x*x0+y*y0+z*z0
  if dw<0:dz,dw=-dz,-dw
  angles.append(math.degrees(2*math.atan2(dz,dw)))
 return {'motor_rpm_first_sample':float(drive[0]['motor_rpm']),'cog_rpm_first_sample':float(drive[0]['cog_rpm']),'target_angle_after_stop_degrees':float(drive[-1]['target_degrees']),'actual_angle_final_degrees':angles[-1],'last_five_samples_range_degrees':max(angles[-5:])-min(angles[-5:]),'motor_stopped_at_tick':260,'last_sample_tick':360,'test_only_impulse_applied':False,'other_axes_independently_driven':False,'foot_contact_tested':False}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('directory',type=Path);print(json.dumps(analyze(p.parse_args().directory),indent=2))
