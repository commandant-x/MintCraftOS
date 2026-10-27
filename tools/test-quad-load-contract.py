#!/usr/bin/env python3
"""A quiet airframe must not certify an oscillating payload or stale observations."""
import copy
from quad_load_contract import evaluate_load
keys='x y z vx vy vz pitch yaw roll tilt attitude_error target_y target_pitch target_roll forward left vertical phase residual saturated load_bias rope_stretch course rope_angle'.split()
rows=[]
for i in range(1201):
 r={k:0.0 for k in keys};r.update(t=i*.05,y=80,target_y=80)
 for j in range(1,5):r['u'+str(j)]=14;r['rpm'+str(j)]=16
 rows.append(r)
event=dict(status='COMPLETE',reason='',frames='1200')
assert evaluate_load(rows,event,'load-swing',60)['status']=='PASS'
for kind in ('swing','stale','incomplete','speed','motion-missing'):
 rr=copy.deepcopy(rows);e=event.copy();case='load-swing'
 if kind=='swing':
  for r in rr:r['rope_angle']=20
 if kind=='stale':rr[700]['t']=rr[699]['t']
 if kind=='incomplete':e['status']='FAULT'
 if kind=='speed':
  for r in rr:r['vy']=1
 if kind=='motion-missing':
  case='brake'
  for r in rr:
   if 5<=r['t']<10:r['forward']=1
 assert evaluate_load(rr,e,case,60)['status']=='FAIL',kind
print('Suspended-load contract: quiet hover passes; oscillating cable, stale data, fault, residual speed and unexecuted motion fail')
