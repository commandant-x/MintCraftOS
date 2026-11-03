#!/usr/bin/env python3
"""Verify and summarize the held-chassis twelve-axis reverse test."""
import csv,json,math,sys
from pathlib import Path

def q(row,prefix):
 vals=[float(row[prefix+'_'+c]) for c in ('qx','qy','qz','qw')];n=math.sqrt(sum(v*v for v in vals))
 if not math.isfinite(n) or abs(n-1)>.01:raise ValueError('invalid quaternion')
 return [v/n for v in vals]
def mul(a,b):
 x,y,z,w=a;X,Y,Z,W=b;return [w*X+x*W+y*Z-z*Y,w*Y-x*Z+y*W+z*X,w*Z+x*Y-y*X+z*W,w*W-x*X-y*Y-z*Z]
def inv(a):return [-a[0],-a[1],-a[2],a[3]]
def analyze(folder):
 folder=Path(folder)
 if not (folder/'complete.txt').is_file() or (folder/'error.txt').exists():raise ValueError('fixture did not pass')
 rows=list(csv.DictReader((folder/'drive.csv').open()));legs=('front_left','front_right','rear_left','rear_right');axes=('roll','hip','knee');result=[]
 if len(rows)!=24:raise ValueError('expected 24 samples')
 for case in range(12):
  f,r=rows[2*case:2*case+2];leg=legs[case//3];axis=axes[case%3]
  if int(f['case'])!=case or int(r['case'])!=case or f['phase']!='forward' or r['phase']!='reverse':raise ValueError('bad case ordering')
  for row in (f,r):
   if abs(float(row['motor_rpm'])-128)>.01:raise ValueError('motor speed')
   for i in range(12):
    key=legs[i//3]+'_'+axes[i%3]+'_rpm';v=float(row[key]);expected=64 if i==case else 0
    if abs(abs(v)-expected)>.01:raise ValueError('speed for '+key+' case '+str(case))
  key=leg+'_'+axis+'_rpm';forward=float(f[key]);reverse=float(r[key])
  if abs(forward+reverse)>.01:raise ValueError('reverse failed')
  parent='chassis' if axis=='roll' else leg+'_roll' if axis=='hip' else leg+'_hip';child=leg+'_'+axis
  a=mul(inv(q(f,parent)),q(f,child));b=mul(inv(q(r,parent)),q(r,child));d=mul(b,inv(a));change=math.degrees(2*math.acos(min(1,abs(d[3]))))
  result.append({'leg':leg,'axis':axis,'forward_rpm':forward,'reverse_rpm':reverse,'relative_orientation_change_between_samples_degrees':change})
 audit=(folder/'audit.txt').read_text();events=(folder/'events.tsv').read_text()
 if 'pivots=12 leg_bodies=12 chassis=1 motor_count_observed=1' not in audit or 'total mass=10000.0' not in events:raise ValueError('structure or mass not verified')
 return {'motor_count':1,'motor_rpm':128,'joint_reduction':'2:1','mass_sable_units':10000,'slime_feet':4,'selected_cases':result,'limitations':'one held-chassis run with test-only adjacent redstone blocks; no Sputnik receiver, foot contact, unsupported standing, walking, or positioning accuracy qualification; orientation change is the difference between two samples, not a full trajectory or angle error'}
if __name__=='__main__':print(json.dumps(analyze(sys.argv[1]),indent=2))
