#!/usr/bin/env python3
"""Verify observed shaft isolation; does not qualify a loaded walking robot."""
import argparse,csv,json,math
from pathlib import Path

def check(path):
 with path.open(newline='') as stream:rows=list(csv.DictReader(stream))
 expected=['all_connected']+[f'branch_{i}_disconnected' for i in range(1,5)]+['all_reconnected']
 if [r['phase'] for r in rows]!=expected:raise ValueError('missing, repeated or misordered phases')
 expected_ticks=[200,280,380,480,580,700]
 for row,tick in zip(rows,expected_ticks):
  if int(row['tick'])!=tick:raise ValueError('unexpected sampling tick')
  source=float(row['source_rpm']);v=[float(row[f'branch{i}_rpm']) for i in range(1,5)]
  if not all(map(math.isfinite,[source,*v])) or abs(source-64)>0.01:raise ValueError('source speed or finite data invalid')
  cut=int(row['phase'].split('_')[1])-1 if row['phase'].startswith('branch_') else -1
  for i,n in enumerate(v):
   if abs(n-([64,-64,64,-64][i] if i!=cut else 0))>.01:raise ValueError('branch failed isolation or direction contract')
 return {'complete':True,'single_source_constructed':True,'branch_isolation':True,'source_rpm':64,'observed_signed_branch_rpm':[64,-64,64,-64],'physical_walking_tested':False,'load_or_position_control_tested':False}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('csv',type=Path);a=p.parse_args();print(json.dumps(check(a.csv),indent=2))
