#!/usr/bin/env python3
"""Inspect measured support geometry and aborts during the reduced gait attempt."""
import argparse,csv,json,math,re
from pathlib import Path
ORDER=('rear_left','front_right','front_left','rear_right');LEGS=('front_left','front_right','rear_left','rear_right')
def margin(point,tri):
 area=(tri[1][0]-tri[0][0])*(tri[2][1]-tri[0][1])-(tri[1][1]-tri[0][1])*(tri[2][0]-tri[0][0]);sgn=1 if area>0 else -1
 if abs(area)<1e-9:return None
 distances=[]
 for a,b in zip(tri,tri[1:]+tri[:1]):
  dx,dz=b[0]-a[0],b[1]-a[1];distances.append(sgn*(dx*(point[1]-a[1])-dz*(point[0]-a[0]))/math.hypot(dx,dz))
 return min(distances)
def analyze(p):
 with (p/'stand.csv').open(newline='') as f:rows={int(r['tick']):r for r in csv.DictReader(f)}
 last=max(rows);expected=[280]+list(range(290,last+1,10))
 if sorted(rows)!=expected or last<340:raise ValueError('incomplete trace')
 if rows[280]['chassis_locked']!='true' or any(rows[t]['chassis_locked']!='false' for t in rows if t>280):raise ValueError('unexpected chassis lock state')
 if any(r[leg+'_'+axis+'_locked']!='false' for r in rows.values() for leg in LEGS for axis in ('roll','hip','knee')):raise ValueError('leg remains staff-locked')
 def xyz(r):return tuple(float(r[k]) for k in ('x','y','z'))
 def q(r):
  v=[float(r[k]) for k in ('qx','qy','qz','qw')];norm=math.sqrt(sum(x*x for x in v))
  if not math.isfinite(norm) or abs(norm-1)>.01:raise ValueError('invalid quaternion')
  return [x/norm for x in v]
 base=rows[330];x0,y0,z0=xyz(base);q0=q(base);angles=[];drops=[]
 for t in sorted(rows):
  if t<340:continue
  r=rows[t];dot=abs(sum(a*b for a,b in zip(q0,q(r))));angles.append(math.degrees(2*math.acos(min(1,dot))));drops.append(y0-float(r['y']))
 cycles=[]
 events=re.findall(r'^(\d+)\tGait cycle=(\d+) leg=([a-z_]+)',(p/'events.tsv').read_text(),re.M)
 if not events:raise ValueError('missing gait cycle events')
 for tick,idx,event_leg in events:
  t=int(tick);n=int(idx)
  if t not in rows or event_leg!=ORDER[n%4]:raise ValueError('inconsistent cycle event')
  r=rows[t];com=(float(r['com_x']),float(r['com_z']));tri=[(float(r[a+'_foot_x']),float(r[a+'_foot_z'])) for a in LEGS if a!=ORDER[n%4]]
  if not all(math.isfinite(v) and abs(v)<1e6 for v in com):raise ValueError('invalid center-of-mass world coordinates')
  before=float(r[ORDER[n%4]+'_foot_y']);available=[rows[k] for k in range(t,min(t+101,last)+1,10) if k in rows];peak=max(float(x[ORDER[n%4]+'_foot_y']) for x in available)
  case={'index':n,'leg':ORDER[n%4],'start_tick':t,'sampled_peak_lift_blocks':peak-before,'finished_return_phase':t+90<=last,'projected_com_xz':com,'approx_support_triangle_margin_blocks':margin(com,tri)}
  if t+90<=last:
   case['knee_target_at_20']=float(rows[t+20]['test_knee_target']);case['hip_target_at_40']=float(rows[t+40]['test_hip_target'])
   case['knee_return_target']=float(rows[t+90]['test_knee_target']);case['hip_return_target']=float(rows[t+90]['test_hip_target'])
   case['commands_observed']=abs(case['knee_target_at_20'])>1 and abs(case['hip_target_at_40'])>1 and abs(case['knee_return_target'])<.01 and abs(case['hip_return_target'])<.01
  cycles.append(case)
 r=rows[last];x,y,z=xyz(r);abort=(p/'aborted.txt').read_text().strip() if (p/'aborted.txt').exists() else None
 return {'cycles_started':len(cycles),'cycles':cycles,'abort':abort,'last_tick':last,'net_horizontal_displacement_blocks':math.hypot(x-x0,z-z0),'body_displacement_x_blocks':x-x0,'body_displacement_z_blocks':z-z0,'max_orientation_change_degrees':max(angles),'max_vertical_drop_blocks':max(drops),'all_thirteen_bodies_staff_unlocked_after_release':True,'test_guide_present':False,'limitations':'support triangle uses foot centers as a geometric approximation; no contact force, Sputnik control, player, or validated walking'}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('directory',type=Path);print(json.dumps(analyze(p.parse_args().directory),indent=2))
