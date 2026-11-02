#!/usr/bin/env python3
"""Audit one-motor inter-sublevel RPM data; fixed physics staff, not gait."""
import argparse,csv,json,math
from pathlib import Path

def audit(path):
 with path.open(newline='') as f:rows=list(csv.DictReader(f))
 required=['baseline','extended_1','extended_1_and_lateral_0_5','motor_off','motor_on']
 if [r['phase'] for r in rows]!=required:raise ValueError('missing or reordered observations')
 if [int(r['tick']) for r in rows]!=[220,340,460,580,700]:raise ValueError('unexpected sampling ticks')
 for r in rows:
  if r['brass']!='true' or r['linked']!='true' or r['first_locked']!='true' or r['second_locked']!='true':raise ValueError('fixture state invalid')
  values=[float(r[k]) for k in ('motor_rpm','source_joint_rpm','target_joint_rpm','shaft_rpm','second_x','second_y','second_z','endpoint_distance')]
  if not all(math.isfinite(x) for x in values):raise ValueError('nonfinite')
  expected=0 if r['phase']=='motor_off' else 64
  if any(abs(v-expected)>.1 for v in values[:4]):raise ValueError('RPM not transmitted')
 distances=[float(r['endpoint_distance']) for r in rows]
 if abs(distances[1]-distances[0]-1)>.01 or abs(distances[2]-math.sqrt(4**2+.5**2))>.02:raise ValueError('endpoint displacement not measured')
 return {'complete':True,'two_sable_structures':True,'one_creative_motor_in_fixture':True,'brass_universal_rod':True,'rpm_when_powered':64,'rpm_when_stopped':0,'endpoint_distances':distances,'measured_axial_extension':distances[1]-distances[0],'both_staff_locked_during_samples':True,'fixture_repositioned_second_body_between_samples':True,'dynamic_load_or_leg_tested':False}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('trace',type=Path);a=p.parse_args();print(json.dumps(audit(a.trace),indent=2))
