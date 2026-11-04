#!/usr/bin/env python3
"""Audit the actual pivot body orientation; does not certify an assembled leg."""
from pathlib import Path
import argparse,csv,json,math

def audit(path):
 with path.open(newline='') as f: rows=list(csv.DictReader(f))
 if not rows:raise ValueError('missing data')
 by={}
 for r in rows:
  if r['pivot_assembled']!='true' or r['linked']!='true':raise ValueError('pivot or rod disconnected')
  q=[float(r['body_q'+c]) for c in ('x','y','z','w')]
  if not all(math.isfinite(x) for x in q) or abs(sum(x*x for x in q)-1)>.01:raise ValueError('invalid orientation')
  if abs(q[0])>.02 or abs(q[1])>.02:raise ValueError('rotation is not approximately around the Z axis')
  angle=math.degrees(2*math.atan2(q[2],q[3]));by.setdefault(r['phase'],[]).append((int(r['tick']),angle,r))
 def tail(phase):
  arr=by.get(phase,[])
  if len(arr)<5:raise ValueError('missing '+phase)
  return arr[-5:]
 on,off=tail('released_on'),tail('released_off')
 for t in (on,off):
  if any(row['locked']!='false' for _,_,row in t):raise ValueError('staff locked')
  if any(b[0]-a[0]!=10 for a,b in zip(t,t[1:])):raise ValueError('missing samples')
 def mean(a):return sum(x[1] for x in a)/len(a)
 onmean,offmean=mean(on),mean(off);delta=(offmean-onmean+180)%360-180
 span=lambda a:max(x[1] for x in a)-min(x[1] for x in a)
 return {'complete':True,'pivot_assembled_sampled':True,'pivot_powered_states':sorted({r['pivot_powered'] for r in rows}),'sampled_on_mean_z_degrees':onmean,'sampled_off_mean_z_degrees':offmean,'sampled_change_z_degrees':delta,'on_final_five_span_degrees':span(on),'off_final_five_span_degrees':span(off),'rotation_over_5_degrees':abs(delta)>=5,'off_motion_under_2_degrees':span(off)<=2,'single_axis_fixture_only':True,'full_leg_or_walking_tested':False}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('trace',type=Path);a=p.parse_args();print(json.dumps(audit(a.trace),indent=2))
