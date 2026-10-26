#!/usr/bin/env python3
"""Reject missing motion, stale observations and hidden load oscillation."""
from quad_com_contract import fixtures_com,evaluate_com
from quad_campaign_contract import MOVEMENTS
import copy
f=fixtures_com()[0];f['episodes']=[dict(start=5,end=5)]
rows=[dict(t=i*.05,x=0,y=80,z=0,vx=0,vy=0,vz=0,pitch=0,yaw=0,roll=0,tilt=0,attitude_error=0,target_y=80,target_pitch=0,target_roll=0,forward=0,left=0,vertical=0,phase=0,u1=14,u2=14,u3=14,u4=14,rpm1=16,rpm2=16,rpm3=16,rpm4=16,residual=0,saturated=0,load_bias=0,rope_stretch=0,course=0) for i in range(1201)]
event=dict(status='COMPLETE',reason='',frames='1200')
assert evaluate_com(rows,event,'hover',60,f)['status']=='PASS'
for kind in ('duplicate','gap','oscillation','target-reset','incomplete','no-motion'):
 r=copy.deepcopy(rows);e=event.copy();movement='hover'
 if kind=='duplicate':r[300]['t']=r[299]['t']
 if kind=='gap':r[300]['t']+=.02
 if kind=='oscillation':
  for row in r:
   if 5<=row['t']<=50:row['vy']=2;row['y']=82
 if kind=='target-reset':r[300]['target_y']=81
 if kind=='incomplete':e['status']='FAULT'
 if kind=='no-motion':
  movement='brake'
  for row in r:
   if 5<=row['t']<10:row['forward']=1;row['phase']=1
 assert evaluate_com(r,e,movement,60,f)['status']=='FAIL',kind
print('COM contract: stable observations pass; duplicate, gap, persistent oscillation, target reset, incomplete and unexecuted motion fail')
