#!/usr/bin/env python3
"""Meaningful scoring regressions: oscillation and ignored commands cannot certify flight."""
import copy
from quad_campaign_contract import evaluate,fixtures,MOVEMENTS

def trace():
 return [dict(t=i/20,x=0,y=80,z=0,vx=0,vy=0,vz=0,tilt=0,attitude_error=0,target_y=80,forward=0,left=0,vertical=0,rope_stretch=0) for i in range(1201)]
event=dict(status='COMPLETE',reason='')
r=trace();assert evaluate(r,event,'hover',60)['status']=='PASS'
# Mean and final height can be correct while ±20m resonance remains catastrophic.
r=trace()
for i,v in enumerate(r):
 if v['t']>50:v['y']=80+(20 if i%2 else -20)
r[-1]['y']=80
result=evaluate(r,event,'hover',60);assert result['status']=='FAIL' and 'tail_height_span' in result['failures'] and 'tail_height_peak' in result['failures']
# A motion flag with physically stationary output is never a successful movement.
r=trace()
for v in r:
 if 5<=v['t']<10:v['forward']=1
assert 'motion' in evaluate(r,event,'forward',60)['failures']
# Intended tilt during travel is allowed; the exact same tilt in terminal hold fails.
r=trace()
for v in r:
 v['z']=max(0,min(10,2*(v['t']-5)))
 if 5<=v['t']<10:v.update(forward=1,tilt=20)
assert evaluate(r,event,'forward',60)['status']=='PASS'
for v in r:
 if v['t']>50:v['tilt']=20
assert 'tail_tilt' in evaluate(r,event,'forward',60)['failures']
assert evaluate(trace()[:100],dict(status='FAULT',reason='telemetry lost'),'hover',60)['status']=='FAIL'
assert evaluate([],dict(status='REFUSED',reason='unsupported'),'hover',60)['status']=='REFUSED'
assert len(fixtures())==24 and len(MOVEMENTS)==24
assert len({x['id'] for x in fixtures()})==24
print('Campaign scoring: zero-mean vertical resonance, missing motion, active vs held tilt, incomplete traces and explicit refusal passed')
