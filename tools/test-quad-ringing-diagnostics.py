#!/usr/bin/env python3
import importlib.util,math
from pathlib import Path
s=importlib.util.spec_from_file_location('ringing',Path(__file__).with_name('analyze-sputnik-quad-ringing.py'));m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
def rows():return [dict(t=i*.05,y=80,target_y=80,attitude_error=0,vy=0,vx=0,vz=0,forward=0,left=0,vertical=0,pitch=0,roll=0,target_pitch=0,target_roll=0) for i in range(1201)]
a=rows();r=m.transient(a,'cold-hover');assert r['valid'] and r['durable_settling_seconds']==0
for x in a:
 if 2<x['t']<30:x['y']+=2*math.sin(x['t']*3)
r=m.transient(a,'cold-hover');assert r['durable_settling_seconds']>=29 and r['reexits_after_stable_window']>=1,'early or late-only stable window hid ringing'
a=rows();a[-1]['vy']=1;r=m.transient(a,'cold-hover');assert r['durable_settling_seconds'] is None,'late exit ignored'
a=rows();a[10]['t']=a[9]['t'];assert not m.transient(a,'cold-hover')['valid']
a=rows();a[4]['vy']=math.nan;assert not m.transient(a,'cold-hover')['valid']
assert not m.transient(rows()[:-1],'cold-hover')['valid']
assert m.release_time('reverse-command')==15 and m.release_time('vertical-cycle')==20
print('Transient diagnostics reject hidden pre-settling resonance, late exits, stale/incomplete/nonfinite traces; release phases verified')
