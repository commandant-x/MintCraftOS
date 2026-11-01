#!/usr/bin/env python3
"""Summarize native linkage bench evidence without treating completion as a pass."""
from pathlib import Path
import argparse,csv,json,math

def analyze(path):
 with path.open(newline='') as f: rows=list(csv.DictReader(f))
 if not rows: raise ValueError('empty trace')
 last=-1
 for row in rows:
  tick=int(row['tick'])
  if tick<=last:raise ValueError('nonmonotonic ticks')
  last=tick
  for k in ('source_rpm','regulator_rpm','target_tenths','signal','body_x','body_y','body_z'):
   if not math.isfinite(float(row[k])):raise ValueError('nonfinite '+k)
 def group(name):return [r for r in rows if r['phase']==name]
 def one(name):
  found=group(name)
  if len(found)!=1:raise ValueError('missing or repeated '+name)
  return found[0]
 off=one('off_locked');on=one('on_locked');moving=group('released_on');returned=group('released_off');stopped=group('motor_stopped_on')
 if not moving or not returned or not stopped:raise ValueError('incomplete phases')
 if any(r['linked']!='true' for r in rows):raise ValueError('link lost')
 if off['locked']!='true' or on['locked']!='true' or any(r['locked']!='false' for r in moving+returned+stopped):raise ValueError('unexpected lock state')
 def rpm(row):return abs(float(row['source_rpm']))
 if abs(rpm(off)-64)>.1 or abs(rpm(on)-64)>.1 or any(rpm(r)>.1 for r in stopped):raise ValueError('incorrect source speed')
 if float(off['signal'])!=0 or float(on['signal'])!=15 or any(float(r['signal'])!=0 for r in returned) or any(float(r['signal'])!=15 for r in stopped):raise ValueError('unexpected input signal')
 extension=float(moving[-1]['body_x'])-float(off['body_x']);retraction=float(returned[-1]['body_x'])-float(moving[-1]['body_x'])
 def span(group,key):
  vals=[float(r[key]) for r in group];return max(vals)-min(vals)
 return_span=span(returned,'body_x');tail=returned[-5:]
 tail_range=max(span(tail,k) for k in ('body_x','body_y','body_z'))
 return {'complete':True,'source_count_in_fixture':1,'link_intact_at_sampled_ticks':True,'powered_target_low_tenths':int(off['target_tenths']),'powered_target_high_tenths':int(on['target_tenths']),'released_extension_x_blocks':extension,'released_return_x_blocks':retraction,'return_signal':0,'return_target_tenths':int(returned[-1]['target_tenths']),'return_target_changed':int(returned[-1]['target_tenths'])==int(off['target_tenths']),'return_motion_observed':retraction<-.1,'return_x_span_blocks':return_span,'return_final_five_sample_max_axis_span_blocks':tail_range,'return_final_motion_below_0_2_blocks':len(tail)==5 and tail_range<=.2,'return_observed_and_stable':int(returned[-1]['target_tenths'])==int(off['target_tenths']) and retraction<-.1 and len(tail)==5 and tail_range<=.2,'motor_stopped_signal':15,'motor_stopped_target_tenths':int(stopped[-1]['target_tenths']),'physical_leg_or_walking_tested':False}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('trace',type=Path);args=p.parse_args();print(json.dumps(analyze(args.trace),indent=2))
