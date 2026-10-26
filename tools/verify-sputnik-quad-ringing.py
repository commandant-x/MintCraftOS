#!/usr/bin/env python3
"""Independently recalculate the published transient research from exact traces."""
import argparse,collections,csv,hashlib,importlib.util,io,json,zipfile
from pathlib import Path
from quad_campaign_contract import evaluate
ROOT=Path(__file__).resolve().parent.parent
spec=importlib.util.spec_from_file_location('ringing',Path(__file__).with_name('analyze-sputnik-quad-ringing.py'));diag=importlib.util.module_from_spec(spec);spec.loader.exec_module(diag)
def digest(data):return hashlib.sha256(data).hexdigest()
def rows(data):return [{k:float(v) for k,v in r.items()} for r in csv.DictReader(io.StringIO(data.decode()))]
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--report',type=Path,required=True);a=p.parse_args();out=a.report
 art=json.loads((out/'artifacts.json').read_text());explore=json.loads((out/'explorations.json').read_text());native=json.loads((out/'native-interventions.json').read_text())
 shipped=(ROOT/'platforms/sputnik/dist/mintcraft-autopilot-quad-fpv.lua').read_bytes();assert digest(shipped)==art['unchanged_controller_sha256']==native['manifest']['controller_sha256']
 assert (ROOT/'platforms/sputnik/dist/mintcraft-sputnik-0.3.2.zip').stat().st_size==962528
 total=0;frames=0;events=collections.Counter();hashes=set()
 for name,rec in art['archives'].items():
  file=out/name;assert file.stat().st_size==rec['bytes'] and digest(file.read_bytes())==rec['sha256'];assert file.stat().st_size<95000000
  with zipfile.ZipFile(file) as z:
   assert z.testzip() is None
   if name=='native-interventions.zip':
    assert z.read('frozen-sources/platforms/sputnik/dist/mintcraft-autopilot-quad-fpv.lua')==shipped
    assert digest(z.read('plant.lua'))==native['manifest']['plant_sha256']
    for r in native['cases']:
     prefix=r['fixture']+'/';data=z.read(prefix+r['movement']+'.csv');assert digest(data)==r['trace_sha256'];trace=rows(data)
     ev=next(x for x in csv.DictReader(io.StringIO(z.read(prefix+'events.csv').decode())) if x['case']==r['movement'])
     score=evaluate(trace,ev,r['movement'],60)
     for k in ('status','failures','metrics','criteria'):assert r[k]==score[k]
     assert diag.transient(trace,r['movement'])==r['transient']
     degrees=float(r['fixture'].rsplit('tilt',1)[1]);assert abs(trace[0]['tilt']-degrees)<1e-5
    continue
   stage=int(name.removeprefix('exploratory-traces-').removesuffix('.zip'))
   profiles=[v for v in explore['prototypes'] if v['stage']==stage]
   for v in profiles:
    assert digest(z.read(v['name']+'/controller.lua'))==v['controller_sha256'];hashes.add(v['controller_sha256'])
    for r in v['cases']:
     prefix=v['name']+'/'+r['fixture']+'/';data=z.read(prefix+r['movement']+'.csv');assert digest(data)==r['trace_sha256'];trace=rows(data)
     ev=next(x for x in csv.DictReader(io.StringIO(z.read(prefix+'events.csv').decode())) if x['case']==r['movement']);assert ev['status'] in ('COMPLETE','FAULT','REFUSED')
     score=evaluate(trace,ev,r['movement'],60)
     for k in ('status','failures','metrics','criteria'):assert r[k]==score[k],(v['name'],r['fixture'],r['movement'],k)
     assert diag.transient(trace,r['movement'])==r['transient']
     events[ev['status']]+=1;frames+=int(float(ev['frames']));total+=1
 assert total==art['exploratory_cases_verified']==1692 and len(hashes)==explore['distinct_controllers']==46
 assert frames==explore['simulated_controller_frames'] and dict(events)==explore['events']
 baseline=json.loads((out/'native-campaign-transients.json').read_text());old=ROOT/'platforms/sputnik/reports/quad-campaign-0.3.2'
 assert digest((old/'results.json').read_bytes())==baseline['source_results_sha256']
 with zipfile.ZipFile(old/'campaign-traces-fpv.zip') as z:
  for r in baseline['cases']:
   data=z.read('traces/'+r['fixture']+'/'+r['controller']+'/'+r['movement']+'.csv');assert digest(data)==r['trace_sha256']
   score=diag.transient(rows(data),r['movement'])
   for k,v in score.items():assert r[k]==v
 print('Verified 552 prior native transients, 72 new native interventions, 1692 exploratory cases / 46 distinct controllers, exact trace/controller SHA, archive CRC and unchanged flight distribution')
if __name__=='__main__':main()
