#!/usr/bin/env python3
"""Inspect selective redstone forward/reverse, targets, and physical poses."""
import argparse,csv,json,math
from pathlib import Path
from analyze_redstone import angle

def analyze(path,reloaded=False,ground_contact=False):
 with (path/'poses.csv').open(newline='') as f: poses={int(r['tick']):r for r in csv.DictReader(f)}
 with (path/'drive.csv').open(newline='') as f: drive={int(r['tick']):r for r in csv.DictReader(f)}
 if sorted(poses)!=[230]+list(range(240,681,10)) or sorted(drive)!=list(range(240,681,10)):raise ValueError('incomplete trace')
 if not reloaded and any(poses[230][x+'_locked']!='true' for x in ('hip_roll','hip_pitch','knee')):raise ValueError('wrong initial lock state')
 if any(poses[t][x+'_locked']!='false' for t in range(240,681,10) for x in ('hip_roll','hip_pitch','knee')):raise ValueError('expected released child bodies')
 names=['cog_rpm','hip_cog_rpm','knee_cog_rpm'];spec=[('hip_roll','hip_roll',None,'z',260,310,320,370),('hip_pitch','hip_pitch','hip_roll','x',380,430,440,490),('knee','knee','hip_pitch','x',500,550,560,610)]
 result={}
 for i,(name,child,parent,axis,t0,t1,t2,t3) in enumerate(spec):
  fwd=[float(drive[t][names[i]]) for t in [t0+10,t0+20,t0+30]];rev=[float(drive[t][names[i]]) for t in [t2+10,t2+20,t2+30]]
  other=[float(drive[t][key]) for t in [t0+10,t0+20,t0+30,t2+10,t2+20,t2+30] for j,key in enumerate(names) if j!=i]
  result[name]={'forward_rpm':fwd,'reverse_rpm':rev,'direction_reversed':all(abs(x)>0.01 for x in fwd+rev) and all(x*y<0 for x,y in zip(fwd,rev)),'other_cogs_stopped':all(abs(x)<0.01 for x in other),'forward_physical_degrees':angle(poses[t0],poses[t1],child,parent,axis),'reverse_physical_degrees':angle(poses[t2],poses[t3],child,parent,axis),'net_physical_degrees':angle(poses[t0],poses[t3],child,parent,axis)}
 return {'axes':result,'method':'one creative motor, common redstone reverser, one redstone clutch per axis','control':'test-only redstone block placement; no Sputnik controller','test_only_impulse_applied':False,'foot_contact_tested':ground_contact,'walking_tested':False}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('directory',type=Path);p.add_argument('--reloaded',action='store_true');p.add_argument('--ground-contact',action='store_true');args=p.parse_args();print(json.dumps(analyze(args.directory,args.reloaded,args.ground_contact),indent=2))
