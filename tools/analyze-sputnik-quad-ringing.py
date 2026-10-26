#!/usr/bin/env python3
"""Measure transient settling from complete, immutable 20 Hz quad traces.

These additional diagnostics do not overwrite the historical campaign criteria.
No signal writes or automatic controller tuning occur here.
"""
import argparse,csv,hashlib,io,json,math,zipfile
from pathlib import Path

BANDS=dict(height_m=.3,attitude_deg=2,vertical_mps=.2,horizontal_mps=.3)

def release_time(movement):
 if movement=='vertical-cycle':return 20
 if movement=='reverse-command':return 15
 if movement in ('hover','cold-hover'):return 0
 if movement.startswith('recovery-') or movement=='load-swing':return 5
 return 10

def transient(rows,movement):
 """First >=1s stable window AND final permanently stable suffix, with fresh data."""
 phase=release_time(movement)
 if not rows:return dict(phase_seconds=phase,valid=False,reason='no trace')
 if not all(all(math.isfinite(v) for v in r.values()) for r in rows):return dict(phase_seconds=phase,valid=False,reason='nonfinite')
 if any(abs(b['t']-a['t']-.05)>1e-5 for a,b in zip(rows,rows[1:])):return dict(phase_seconds=phase,valid=False,reason='not fresh 20Hz')
 if rows[-1]['t']<60-1e-5:return dict(phase_seconds=phase,valid=False,reason='incomplete trace')
 horizontal=any(r['forward']!=0 or r['left']!=0 for r in rows)
 samples=[r for r in rows if r['t']>=phase]
 stable=[]
 for r in samples:
  stable.append(abs(r['y']-r['target_y'])<BANDS['height_m'] and r['attitude_error']<BANDS['attitude_deg'] and abs(r['vy'])<BANDS['vertical_mps'] and (not horizontal or math.hypot(r['vx'],r['vz'])<BANDS['horizontal_mps']))
 count=0;first=None;reentries=0;in_window=False
 for r,ok in zip(samples,stable):
  if not ok:
   if in_window:reentries+=1
   count=0;in_window=False
  else:
   count+=1
   if count>=21:
    in_window=True
    if first is None:first=r['t']-phase-1
 last_bad=max((i for i,v in enumerate(stable) if not v),default=-1)
 start=last_bad+1
 durable=samples[start]['t']-phase if len(samples)-start>=21 else None
 h=[r['y']-r['target_y'] for r in samples]
 # Hysteretic excursions; ignore sub-band sample noise and exact zero crossings.
 def excursions(values,band):
  last=0;turns=0
  for v in values:
   side=1 if v>band else -1 if v< -band else 0
   if side and last and side!=last:turns+=1
   if side:last=side
  return turns
 return dict(phase_seconds=phase,valid=True,first_stable_window_seconds=None if first is None else max(0,first),durable_settling_seconds=durable,reexits_after_stable_window=reentries,height_oscillation_reversals=excursions(h,.1),pitch_reversals=excursions([r['pitch']-r['target_pitch'] for r in samples],1),roll_reversals=excursions([r['roll']-r['target_roll'] for r in samples],1),post_phase_height_peak=max(abs(v) for v in h),post_phase_attitude_peak=max(r['attitude_error'] for r in samples))

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--report',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 results=json.loads((a.report/'results.json').read_text());artifacts=json.loads((a.report/'artifacts.json').read_text())
 cases=[]
 for name,rec in artifacts['archives'].items():
  if not name.startswith('campaign-traces-'):continue
  file=a.report/name;assert hashlib.sha256(file.read_bytes()).hexdigest()==rec['sha256'],'Changed trace archive'
  with zipfile.ZipFile(file) as z:
   for r in results['results']:
    if not r['trace'] or not r['trace'].split('/')[1] in name:continue
    data=z.read('traces/'+r['trace']);assert hashlib.sha256(data).hexdigest()==r['trace_sha256']
    rows=[{k:float(v) for k,v in row.items()} for row in csv.DictReader(io.StringIO(data.decode()))]
    cases.append(dict(fixture=r['fixture'],controller=r['controller'],movement=r['movement'],historical_status=r['status'],trace_sha256=r['trace_sha256'],**transient(rows,r['movement'])))
 assert len(cases)==sum(r['trace'] is not None for r in results['results'])
 a.output.mkdir(parents=True,exist_ok=True)
 record=dict(schema=1,bands=BANDS,minimum_stable_seconds=1,source_results_sha256=hashlib.sha256((a.report/'results.json').read_bytes()).hexdigest(),scope='Additional transient diagnostic from exact native LuaJ traces; historical PASS criteria unchanged; no Minecraft qualification',cases=cases)
 (a.output/'transients.json').write_text(json.dumps(record,indent=2)+'\n')
 print('Analyzed',len(cases),'complete or explicitly incomplete native traces; diagnostics do not replace historical acceptance')
if __name__=='__main__':main()
