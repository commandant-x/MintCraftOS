#!/usr/bin/env python3
"""Report measured foot and relative knee orientation for a fixed-root leg bench."""
import csv, json, math, sys
from pathlib import Path
p=Path(sys.argv[1]); feet={int(r['tick']):r for r in csv.DictReader((p/'foot.csv').open())};poses={int(r['tick']):r for r in csv.DictReader((p/'poses.csv').open())}
def mul(a,b):
 x,y,z,w=a; X,Y,Z,W=b
 return (w*X+x*W+y*Z-z*Y,w*Y-x*Z+y*W+z*X,w*Z+x*Y-y*X+z*W,w*W-x*X-y*Y-z*Z)
def inv(q):return (-q[0],-q[1],-q[2],q[3])
def quat(r,n):
 q=tuple(float(r[n+'_q'+k]) for k in 'xyzw'); length=math.sqrt(sum(v*v for v in q));return tuple(v/length for v in q)
def rel(r):return mul(inv(quat(r,'hip_pitch')),quat(r,'knee'))
base=rel(poses[250]); result=[]
for t in (250,270,282,294,310,340,352,364,380,410):
 if t not in feet or t not in poses:continue
 r=feet[t];q=mul(inv(base),rel(poses[t]));n=math.sqrt(sum(v*v for v in q));angle=math.degrees(2*math.acos(min(1,abs(q[3]/n))))
 result.append({'tick':t,'foot':[float(r[k]) for k in ('x','y','z')],'knee_change_degrees':angle})
print(json.dumps({'samples':result,'note':'Fixed root, leg unloaded; foot positions do not prove ground contact or loaded performance.'},indent=2))
