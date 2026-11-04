#!/usr/bin/env python3
"""Check selective cog speeds and measured relative motion for the three-axis bench."""
import csv, json, math, sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'spot-leg'))
from analyze_redstone import angle

def analyze(folder):
 folder=Path(folder)
 poses={int(r['tick']):r for r in csv.DictReader((folder/'poses.csv').open())}
 drive={int(r['tick']):r for r in csv.DictReader((folder/'drive.csv').open())}
 if not (folder/'complete.txt').is_file() or (folder/'error.txt').exists():raise ValueError('fixture did not finish without error')
 axes=[('roll','hip_roll',None,'z',261,260,276,'cog_rpm'),('hip','hip_pitch','hip_roll','x',281,280,296,'hip_cog_rpm'),('knee','knee','hip_pitch','x',301,300,316,'knee_cog_rpm')]
 signals=('cog_rpm','hip_cog_rpm','knee_cog_rpm');results={}
 for name,child,parent,axis,t,a,b,selected in axes:
  row=drive[t];motor=float(row['motor_rpm']);values={k:float(row[k]) for k in signals};motion=angle(poses[a],poses[b],child,parent,axis)
  if abs(abs(motor)-128)>0.01 or abs(abs(values[selected])-64)>0.01 or any(abs(values[k])>0.01 for k in signals if k!=selected):raise ValueError('wrong selective speed at '+name+': '+str(row))
  if not math.isfinite(motion) or abs(motion)<1:raise ValueError('no measurable physical motion: '+name)
  results[name]={'sample_tick':t,'motor_rpm':motor,'selected_cog_rpm':values[selected],'other_cogs_rpm':{k:values[k] for k in signals if k!=selected},'relative_physical_rotation_degrees_over_16_ticks':motion}
 audit=(folder/'audit.txt').read_text()
 if 'lower_planks=7 upper_planks=7' not in audit or 'pivot_count=3' not in audit:raise ValueError('incomplete leg structure')
 return {'motor_count':1,'motor_rpm':128,'reduction_per_joint':'2:1','axes':results,'limitations':'one unloaded isolated leg; motor reversal and independent per-axis reverse on this leg are not tested; no Sputnik control, 10 t body, contact sensing, or walking test; physical rotations are not a positioning-accuracy test'}
if __name__=='__main__':print(json.dumps(analyze(sys.argv[1]),indent=2))
