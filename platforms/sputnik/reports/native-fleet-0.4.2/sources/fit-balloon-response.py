"""Estimate observed effective gas response from an instrumented Minecraft trace.
This closed-loop estimate is descriptive; it does not qualify an actuator or
provide a gas sensor to the deployed Sputnik Lua.
"""
import argparse,csv,json,math,statistics
p=argparse.ArgumentParser(description=__doc__);p.add_argument('trace');p.add_argument('--capacity',type=float,required=True,help='Native accepted burner setting, not envelope capacity');a=p.parse_args()
if not math.isfinite(a.capacity) or a.capacity<=0:p.error('positive measured capacity required')
rows=list(csv.DictReader(open(a.trace)));bins={'fill':[],'drain':[]}
for before,after in zip(rows,rows[1:]):
 if int(before['tick'])<320 or int(after['universe_tick'])-int(before['universe_tick'])!=1:continue
 if before.get('gas_provider_associated')!='1' or after.get('gas_provider_associated')!='1':continue
 rate=(float(after['gas_volume'])-float(before['gas_volume']))*20
 error=a.capacity*float(before['burner_signal'])/15-float(before['gas_volume'])
 if abs(error)>5 and abs(rate)>1 and error*rate>0:bins['fill' if error>0 else 'drain'].append(error/rate)
result={'capacity':a.capacity,'scope':'effective first-order time in closed-loop observations; one-tick alignment and state-dependent native response remain limitations','seconds':{}}
for name,values in bins.items():
 values.sort();result['seconds'][name]={'samples':len(values),'median':statistics.median(values) if values else None,'p10':values[len(values)//10] if values else None,'p90':values[len(values)*9//10] if values else None}
print(json.dumps(result,indent=2))
