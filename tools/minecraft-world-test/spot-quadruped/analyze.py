#!/usr/bin/env python3
"""Analyze twelve selected redstone directions and the unassisted chassis release."""
import argparse,csv,json,math
from pathlib import Path
LEGS=('front_left','front_right','rear_left','rear_right');AXES=('roll','hip','knee')
def mul(a,b):
 x,y,z,w=a;X,Y,Z,W=b;return (w*X+x*W+y*Z-z*Y,w*Y-x*Z+y*W+z*X,w*Z+x*Y-y*X+z*W,w*W-x*X-y*Y-z*Z)
def inv(q):x,y,z,w=q;return (-x,-y,-z,w)
def q(row,name):
 v=[float(row[(name+'_' if name else '')+c]) for c in ('qx','qy','qz','qw')];n=math.sqrt(sum(x*x for x in v))
 if not math.isfinite(n) or abs(n-1)>.01:raise ValueError('invalid quaternion for '+name)
 return [x/n for x in v]
def angle(before,after,leg,axis):
 child=leg+'_'+axis;parent='chassis' if axis=='roll' else leg+('_roll' if axis=='hip' else '_hip')
 def rel(r):return mul(inv(q(r,parent)),q(r,child))
 v=mul(rel(after),inv(rel(before)));v=[-x for x in v] if v[3]<0 else v
 return math.degrees(2*math.atan2(v[2 if axis=='roll' else 0],v[3]))
def analyze(path):
 with (path/'drive.csv').open(newline='') as f:rows=list(csv.DictReader(f))
 groups={}
 for r in rows:groups.setdefault(int(r['case']),{})[r['phase']]=r
 if set(groups)!=set(range(12)):raise ValueError('not all twelve cases recorded')
 results=[]
 for i in range(12):
  g=groups[i];leg=LEGS[i//3];axis=AXES[i%3];selected=leg+'_'+axis+'_rpm'
  if set(g)!={'before','forward','forward_end','reverse','reverse_end'}:raise ValueError('incomplete phases in case '+str(i))
  f,r=float(g['forward'][selected]),float(g['reverse'][selected]);others=[float(g[phase][other+'_'+a+'_rpm']) for phase in ('forward','reverse') for other in LEGS for a in AXES if other+'_'+a+'_rpm'!=selected]
  change=angle(g['before'],g['forward_end'],leg,axis);back=angle(g['forward_end'],g['reverse_end'],leg,axis);net=angle(g['before'],g['reverse_end'],leg,axis)
  results.append({'leg':leg,'axis':axis,'forward_rpm':f,'reverse_rpm':r,'direction_reversed':abs(f)>.01 and abs(r)>.01 and f*r<0,'other_cogs_stopped':all(abs(v)<.01 for v in others),'forward_rotation_deg':change,'return_rotation_deg':back,'net_rotation_deg':net,'movement_over_3_deg':abs(change)>=3,'return_observed':abs(back)>=3 and change*back<0})
 with (path/'stand.csv').open(newline='') as f:stand=list(csv.DictReader(f))
 if [int(r['tick']) for r in stand]!=[1280]+list(range(1290,1501,10)):raise ValueError('incomplete stand trace')
 if stand[0]['chassis_locked']!='true' or any(r['chassis_locked']!='false' for r in stand[1:]):raise ValueError('wrong chassis lock sequence')
 x0,y0,z0=(float(stand[0][k]) for k in ('x','y','z'));q0=q(stand[0],'');samples=[]
 for r in stand[1:]:
  x,y,z=(float(r[k]) for k in ('x','y','z'));qq=q(r,'');d=abs(sum(a*b for a,b in zip(q0,qq)));tilt=math.degrees(2*math.acos(min(1,d)))
  samples.append({'tick':int(r['tick']),'horizontal_displacement_blocks':math.hypot(x-x0,z-z0),'vertical_drop_blocks':y0-y,'orientation_change_deg':tilt,'foot_center_heights':[float(r[leg+'_foot_y']) for leg in LEGS]})
 return {'axis_cases':results,'rpm_direction_successes':sum(r['direction_reversed'] and r['other_cogs_stopped'] for r in results),'physical_round_trip_observed':sum(r['movement_over_3_deg'] and r['return_observed'] for r in results),'standing':{'floor_top_y':166,'initial_chassis_y':y0,'max_drop_blocks':max(s['vertical_drop_blocks'] for s in samples),'max_horizontal_displacement_blocks':max(s['horizontal_displacement_blocks'] for s in samples),'max_orientation_change_deg':max(s['orientation_change_deg'] for s in samples),'last':samples[-1],'contact_force_measured':False,'walking_tested':False}}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('directory',type=Path);print(json.dumps(analyze(p.parse_args().directory),indent=2))
