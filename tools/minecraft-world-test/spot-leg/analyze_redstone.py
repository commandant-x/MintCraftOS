#!/usr/bin/env python3
"""Measure selective clutch speeds and relative pivot motion in the redstone trial."""
import argparse,csv,json,math
from pathlib import Path

def mul(a,b):
 x,y,z,w=a;X,Y,Z,W=b
 return (w*X+x*W+y*Z-z*Y,w*Y-x*Z+y*W+z*X,w*Z+x*Y-y*X+z*W,w*W-x*X-y*Y-z*Z)
def inverse(q):
 x,y,z,w=q;return (-x,-y,-z,w)
def quat(row,name):
 q=[float(row[name+'_q'+c]) for c in 'xyzw'];n=math.sqrt(sum(x*x for x in q))
 if not math.isfinite(n) or abs(n-1)>.01: raise ValueError('invalid quaternion')
 return [x/n for x in q]
def relative(row,child,parent):
 a=quat(row,child)
 return a if parent is None else mul(inverse(quat(row,parent)),a)
def angle(a,b,child,parent,axis):
 q=mul(relative(b,child,parent),inverse(relative(a,child,parent)));q=[-x for x in q] if q[3]<0 else q
 return math.degrees(2*math.atan2(q[2 if axis=='z' else 0],q[3]))
def analyze(path,slow=False,reloaded=False):
 with (path/'poses.csv').open(newline='') as f: poses={int(r['tick']):r for r in csv.DictReader(f)}
 with (path/'drive.csv').open(newline='') as f: drive={int(r['tick']):r for r in csv.DictReader(f)}
 end=900 if slow else 500
 if sorted(poses)!=[230]+list(range(240,end+1,10)) or sorted(drive)!=list(range(240,end+1,10)):raise ValueError('incomplete samples')
 if not reloaded and any(poses[230][x+'_locked']!='true' for x in ('hip_roll','hip_pitch','knee')):raise ValueError('expected initial locks')
 if any(poses[t][x+'_locked']!='false' for t in range(240,end+1,10) for x in ('hip_roll','hip_pitch','knee')):raise ValueError('expected released bodies')
 cases=[('hip_roll','hip_roll',None,'z',260,310,[270,280,290]),('hip_pitch','hip_pitch','hip_roll','x',320,370,[330,340,350]),('knee','knee','hip_pitch','x',380,430,[390,400,410])]
 if slow:cases=[('hip_roll','hip_roll',None,'z',260,430,[390,400,410]),('hip_pitch','hip_pitch','hip_roll','x',440,610,[570,580,590]),('knee','knee','hip_pitch','x',620,790,[750,760,770])]
 names=['cog_rpm','hip_cog_rpm','knee_cog_rpm'];out={}
 for i,(name,child,parent,axis,start,end,ticks) in enumerate(cases):
  speeds={key:[float(drive[t][key]) for t in ticks] for key in names}
  out[name]={'relative_rotation_degrees':angle(poses[start],poses[end],child,parent,axis),'cog_rpm_samples':speeds,'selected_cog_received_rpm':all(abs(x)>0.01 for x in speeds[names[i]]),'other_cogs_stopped':all(abs(x)<0.01 for j,key in enumerate(names) if j!=i for x in speeds[key])}
 return {'axes':out,'one_creative_motor':True,'test_only_impulse_applied':False,'foot_contact_tested':False,'walking_tested':False,'redstone_input_method':'test fixture places or removes adjacent redstone blocks; no Sputnik control tested'}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('directory',type=Path);p.add_argument('--slow',action='store_true');p.add_argument('--reloaded',action='store_true');args=p.parse_args();print(json.dumps(analyze(args.directory,args.slow,args.reloaded),indent=2))
