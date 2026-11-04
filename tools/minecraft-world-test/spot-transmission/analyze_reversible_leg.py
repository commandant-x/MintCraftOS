#!/usr/bin/env python3
"""Verify one-motor, three independent reduced and reversible joints."""
import csv, json, math, sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'spot-leg'))
from analyze_redstone import angle

def analyze(folder):
 folder=Path(folder)
 if not (folder/'complete.txt').is_file() or (folder/'error.txt').exists():raise ValueError('fixture did not finish without error')
 poses={int(r['tick']):r for r in csv.DictReader((folder/'poses.csv').open())}
 drive={int(r['tick']):r for r in csv.DictReader((folder/'drive.csv').open())}
 axes=[('roll','hip_roll',None,'z',260,'cog_rpm'),('hip','hip_pitch','hip_roll','x',300,'hip_cog_rpm'),('knee','knee','hip_pitch','x',340,'knee_cog_rpm')]; keys=('cog_rpm','hip_cog_rpm','knee_cog_rpm');results={}
 for name,child,parent,axis,start,selected in axes:
  samples=[drive[start+1],drive[start+21]];speeds=[]
  for row in samples:
   if abs(float(row['motor_rpm'])-128)>.01:raise ValueError('motor is not 128 rpm')
   v={k:float(row[k]) for k in keys}
   if abs(abs(v[selected])-64)>.01 or any(abs(v[k])>.01 for k in keys if k!=selected):raise ValueError('nonselective or wrong speed '+name)
   speeds.append(v[selected])
  if abs(speeds[0]+speeds[1])>.01:raise ValueError('axis failed to reverse '+name)
  fwd=angle(poses[start],poses[start+16],child,parent,axis);rev=angle(poses[start+20],poses[start+36],child,parent,axis)
  if not all(math.isfinite(x) for x in (fwd,rev)) or abs(fwd)<1 or abs(rev)<1:raise ValueError('physical rotation missing '+name)
  results[name]={'motor_rpm':128,'selected_forward_rpm':speeds[0],'selected_reverse_rpm':speeds[1],'other_cogs_rpm':0,'physical_forward_degrees_over_16_ticks':fwd,'physical_reverse_degrees_over_16_ticks':rev}
 audit=(folder/'audit.txt').read_text()
 if 'lower_planks=7 upper_planks=7' not in audit or 'pivot_count=3' not in audit:raise ValueError('incomplete leg')
 return {'motor_count':1,'reduction_per_joint':'2:1','axes':results,'limitations':'one unloaded isolated leg, no Sputnik input, 10 t load, ground contact, closed-loop positioning, or walking test'}
if __name__=='__main__':print(json.dumps(analyze(sys.argv[1]),indent=2))
