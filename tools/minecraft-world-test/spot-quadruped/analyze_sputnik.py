#!/usr/bin/env python3
"""Inspect actual Redstone Link receiver levels and kinetic speeds during Sputnik control."""
import argparse,csv,json
from pathlib import Path
from analyze_gait_tuned import analyze as gait
LEGS=('front_left','front_right','rear_left','rear_right');AXES=('roll','hip','knee');ORDER=('rear_left','front_right','front_left','rear_right')
def analyze(p):
 with (p/'wireless.csv').open(newline='') as f:rows={int(r['tick']):r for r in csv.DictReader(f)}
 if sorted(rows)!=list(range(290,1401)):raise ValueError('incomplete per-tick wireless trace')
 out=[];multi=0;signal_mismatch=0;unresolved_lag=0
 for t,r in rows.items():
  driven=[(leg,axis) for leg in LEGS for axis in AXES if abs(float(r[leg+'_'+axis+'_rpm']))>.01]
  if len(driven)>1:multi+=1
  for leg,axis in driven:
   if int(r[leg+'_'+axis+'_signal'])!=0:
    signal_mismatch+=1
    prev=rows.get(t-1);nxt=rows.get(t+1);key=leg+'_'+axis
    if prev is None or nxt is None or int(prev[key+'_signal'])!=0 or abs(float(nxt[key+'_rpm']))>.01:unresolved_lag+=1
 for n in range(8):
  start=340+n*120;leg=ORDER[n%4];window=[rows[t] for t in range(start,start+111)]
  movements={}
  for axis in ('hip','knee'):
   speeds=[float(r[leg+'_'+axis+'_rpm']) for r in window];movements[axis]={'positive_rpm_observed':any(v>0.01 for v in speeds),'negative_rpm_observed':any(v<-.01 for v in speeds),'receiver_zero_observed':any(int(r[leg+'_'+axis+'_signal'])==0 for r in window)}
  out.append({'cycle':n,'leg':leg,'axes':movements})
 result_gait=gait(p);result_gait['limitations']='support triangle uses foot centers as an approximation; no contact-force measurement, player or qualified robust walking'
 last=rows[1400];all_closed=all(int(last[leg+'_'+axis+'_signal'])==15 and abs(float(last[leg+'_'+axis+'_rpm']))<.01 for leg in LEGS for axis in AXES)
 return {'cycles':out,'cycles_with_both_directions_on_both_selected_axes':sum(all(v['positive_rpm_observed'] and v['negative_rpm_observed'] and v['receiver_zero_observed'] for v in c['axes'].values()) for c in out),'ticks_with_multiple_cogs_running':multi,'ticks_with_running_cog_and_receiver_powered':signal_mismatch,'such_samples_not_explained_by_one_tick_stop_lag':unresolved_lag,'final_receivers_closed':all_closed,'final_motor_rpm':float(last['motor_rpm']),'gait':result_gait,'limitations':'single run, one unladen robot on a flat instrumented surface; fixture changes operator checkboxes; no player, collision-force measurement, robust autonomy or terrain tests'}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('directory',type=Path);print(json.dumps(analyze(p.parse_args().directory),indent=2))
