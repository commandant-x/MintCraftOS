#!/usr/bin/env python3
"""Check collision callback observations against the retained lower-leg body."""
import argparse,csv,json,re
from pathlib import Path

def analyze(p,free_chassis=False):
 bounds=(p/'foot-body-bounds.txt').read_text();m=re.search(r'minX=(-?\d+), minY=(-?\d+), minZ=(-?\d+), maxX=(-?\d+), maxY=(-?\d+), maxZ=(-?\d+)',bounds)
 if not m:raise ValueError('missing foot body bounds')
 lo=list(map(int,m.group(1,2,3)));hi=list(map(int,m.group(4,5,6)))
 with (p/'contact.csv').open(newline='') as f:rows=list(csv.DictReader(f))
 if [int(r['tick']) for r in rows]!=[230]+list(range(240,681,10)):raise ValueError('incomplete contact observations')
 counts=[int(r['total_callbacks']) for r in rows]
 if any(b<a for a,b in zip(counts,counts[1:])):raise ValueError('non-monotonic callback counts')
 lines=(p/'collisions.txt').read_text().splitlines();matched=0;after=0
 for line in lines:
  m=re.search(r'^(\d+) \| BlockPos\{x=(-?\d+), y=(-?\d+), z=(-?\d+)\} \| BlockPos\{x=(-?\d+), y=(-?\d+), z=(-?\d+)\}',line)
  if not m:raise ValueError('invalid collision record')
  tick,*coords=map(int,m.groups());floor=coords[:3];body=coords[3:]
  if floor[1]==165 and all(a<=b<=c for a,b,c in zip(lo,body,hi)):
   matched+=1
   if tick>230:after+=1
 return {'callback_increase_after_release':counts[-1]-counts[0], 'sampled_contact_records':len(lines),'sampled_records_matching_lower_leg_and_test_floor':matched,'matching_records_after_release':after,'lower_leg_contact_observed_after_release':after>0,'floor':'instrumented solid test block; Sable collision callback','body_support_tested':free_chassis,'walking_tested':False,'interpretation':('free chassis released before movement' if free_chassis else 'root motor and bearing remain fixed to the world')+'; callback counts are contact events, not a force or load measurement'}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('directory',type=Path);print(json.dumps(analyze(p.parse_args().directory),indent=2))
