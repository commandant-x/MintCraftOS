#!/usr/bin/env python3
"""Evaluate sampled body orientations after a test-only angular velocity."""
from pathlib import Path
import argparse,csv,json,math

def analyze(path,axis):
 if axis not in ('knee','hip_pitch','hip_roll'):raise ValueError('unknown axis')
 with path.open(newline='') as f:rows=list(csv.DictReader(f))
 if [int(r['tick']) for r in rows]!=[230]+list(range(240,361,10)):raise ValueError('incomplete samples')
 if rows[0]['phase']!='before_impulse' or any(r['phase']!='after_impulse' for r in rows[1:]):raise ValueError('wrong phases')
 parts=['knee','hip_pitch','hip_roll'];index=parts.index(axis)
 if any(rows[0][name+'_locked']!='true' for name in parts):raise ValueError('not fully clamped before impulse')
 for r in rows[1:]:
  for i,name in enumerate(parts):
   if r[name+'_locked']!=('false' if i<=index else 'true'):raise ValueError('unexpected clamp state')
 def q(r):
  a=[float(r[axis+'_q'+c]) for c in 'xyzw']
  if not all(math.isfinite(x) for x in a):raise ValueError('nonfinite orientation')
  norm=math.sqrt(sum(x*x for x in a))
  if abs(norm-1)>.01:raise ValueError('invalid quaternion')
  return [x/norm for x in a]
 x0,y0,z0,w0=q(rows[0]);values=[];other=[]
 for r in rows[1:]:
  x,y,z,w=q(r)
  # q_current * conjugate(q_initial), a rotation in world coordinates.
  dx=-w*x0+x*w0-y*z0+z*y0;dy=-w*y0+x*z0+y*w0-z*x0;dz=-w*z0-x*y0+y*x0+z*w0;dw=w*w0+x*x0+y*y0+z*z0
  if dw<0:dx,dy,dz,dw=-dx,-dy,-dz,-dw
  principal=dz if axis=='hip_roll' else dx;cross=math.hypot(dx,dy) if axis=='hip_roll' else math.hypot(dy,dz)
  values.append(math.degrees(2*math.atan2(principal,dw)));other.append(math.degrees(2*math.atan2(cross,dw)))
 maximum=max(abs(v) for v in values);tail=values[-5:]
 return {'axis':axis,'complete':True,'motor_rpm':0,'rotation_caused_by_test_impulse':True,'max_sampled_axis_rotation_deg':maximum,'max_sampled_other_rotation_deg':max(other),'last_five_axis_span_deg':max(tail)-min(tail),'rotation_over_5_degrees_observed':maximum>=5,'powered_motion_tested':False,'walking_tested':False}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('trace',type=Path);p.add_argument('axis',choices=['knee','hip_pitch','hip_roll']);a=p.parse_args();print(json.dumps(analyze(a.trace,a.axis),indent=2))
