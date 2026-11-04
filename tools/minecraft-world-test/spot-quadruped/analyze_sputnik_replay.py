#!/usr/bin/env python3
"""Summarize reloaded Sputnik gait, using recorded receiver and body poses."""
import argparse,csv,json,math
from pathlib import Path
LEGS=('front_left','front_right','rear_left','rear_right');AXES=('roll','hip','knee');ORDER=('rear_left','front_right','front_left','rear_right')
def read(p):
 with p.open(newline='') as f:return list(csv.DictReader(f))
def analyze(p):
 rows={int(r['tick']):r for r in read(p/'wireless.csv')}; poses=read(p/'stand.csv')
 if sorted(rows)!=list(range(280,1301)):raise ValueError('incomplete wireless trace')
 q0=[float(poses[0][k]) for k in ('qx','qy','qz','qw')];norm=lambda q: math.sqrt(sum(x*x for x in q));q0=[x/norm(q0) for x in q0]
 def angle(r):
  q=[float(r[k]) for k in ('qx','qy','qz','qw')];return math.degrees(2*math.acos(min(1,abs(sum(a*b for a,b in zip(q0,q))/norm(q)))))
 cycles=[]
 for n in range(8):
  leg=ORDER[n%4];window=[rows[t] for t in range(280+n*120,280+n*120+111)];axes={}
  for axis in ('hip','knee'):
   speeds=[float(r[leg+'_'+axis+'_rpm']) for r in window];axes[axis]={'positive':any(v>.01 for v in speeds),'negative':any(v<-.01 for v in speeds),'receiver_zero':any(int(r[leg+'_'+axis+'_signal'])==0 for r in window)}
  cycles.append({'cycle':n,'leg':leg,'axes':axes})
 first,last=poses[0],poses[-1];dx=float(last['x'])-float(first['x']);dz=float(last['z'])-float(first['z']);end=rows[1300]
 multi=sum(sum(abs(float(r[leg+'_'+axis+'_rpm']))>.01 for leg in LEGS for axis in AXES)>1 for r in rows.values())
 return {'cycles':cycles,'cycles_with_both_directions_on_both_selected_axes':sum(all(all(v.values()) for v in c['axes'].values()) for c in cycles),'net_horizontal_displacement_blocks':math.hypot(dx,dz),'body_displacement_x_blocks':dx,'body_displacement_z_blocks':dz,'max_orientation_change_degrees':max(map(angle,poses)),'max_vertical_drop_blocks':max(float(first['y'])-float(r['y']) for r in poses),'ticks_with_multiple_cogs_running':multi,'final_receivers_closed':all(int(end[leg+'_'+axis+'_signal'])==15 for leg in LEGS for axis in AXES),'final_reverse_signal':int(end['reverse_signal']),'final_motor_rpm':float(end['motor_rpm']),'aborted':(p/'aborted.txt').exists(),'limitations':'one unloaded robot on flat stone; UI checkboxes changed by fixture, no player, force measurement or terrain variation'}
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('directory',type=Path);print(json.dumps(analyze(a.parse_args().directory),indent=2))
