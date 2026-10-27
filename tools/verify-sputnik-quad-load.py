#!/usr/bin/env python3
"""Recompute suspended-load scores; audit intent, hidden payload mass and integer outputs."""
import argparse,csv,hashlib,io,json,math,zipfile
from pathlib import Path
from pypdf import PdfReader
from quad_load_contract import evaluate_load
ROOT=Path(__file__).resolve().parent.parent
def sha(data):return hashlib.sha256(data).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--report',type=Path,required=True);a=p.parse_args();out=a.report
 manifest=json.loads((out/'manifest.json').read_text());results=json.loads((out/'results.json').read_text())['results'];art=json.loads((out/'artifacts.json').read_text());fixtures={s['fixture']['id']:s['fixture'] for s in manifest['states']}
 assert manifest['sources']['baseline']=='bf7b3e3316158a2a5c35c9c32bfee443101b3bb81d6f2d3c99e31a141044c150'
 expected={(s['fixture']['id'],c,name) for s in manifest['states'] for c in ('baseline','fixed') for name in s['cases']}
 assert len(expected)==len(results)==96 and {(r['fixture'],r['controller'],r['movement']) for r in results}==expected
 assert all(g['source']==256 for f in fixtures.values() for g in f['rotors'])
 assert sha((ROOT/'platforms/sputnik/dist/mintcraft-autopilot-quad-fpv.lua').read_bytes())==manifest['sources']['fixed']
 assert sha((ROOT/'platforms/sputnik/dist/mintcraft-autopilot-control.lua').read_bytes())=='f62be0b6c8615597f61518f218198dac66afd645daa89562344c7039dcec4092'
 for name,rec in art['archives'].items():
  file=out/name;assert file.stat().st_size==rec['bytes'] and sha(file.read_bytes())==rec['sha256']
  with zipfile.ZipFile(file) as z:assert z.testzip() is None
 if (out/'rejected-prototype.zip').exists():
  from quad_campaign_contract import evaluate
  with zipfile.ZipFile(out/'rejected-prototype.zip') as z:
   old=json.loads(z.read('manifest.json'));scores=json.loads(z.read('results.json'))
   assert sha(z.read('frozen-sources/controller_fpv.lua'))==old['sources']['controller_fpv']!=manifest['sources']['fixed']
   assert sha(z.read('frozen-sources/criteria.py'))==manifest['sources']['criteria']
   events={e['case']:e for e in csv.DictReader(io.StringIO(z.read('reference/events.csv').decode()))}
   for record in scores:
    rows=[{k:float(v) for k,v in r.items()} for r in csv.DictReader(io.StringIO(z.read('reference/'+record['movement']+'.csv').decode()))]
    assert {k:v for k,v in record.items() if k!='movement'}==evaluate(rows,events[record['movement']],record['movement'],60)
   assert len(scores)==24 and sum(r['status']=='PASS' for r in scores)==22
 count=0
 with zipfile.ZipFile(out/'native-load-traces.zip') as z:
  for k,expected_sha in manifest['sources'].items():
   name='VerifySputnikLua.java' if k=='java_runner' else k+('.py' if k in ('criteria','load_criteria','diagnostics','runner') else '.csv' if k=='pressure' else '.lua')
   assert sha(z.read('frozen-sources/'+name))==expected_sha,k
  assert sha(z.read('frozen-sources/plant.lua'))==manifest['plant_sha256']
  assert sha((ROOT/'tools/quad_load_contract.py').read_bytes())==manifest['sources']['load_criteria']
  assert sha((ROOT/'tools/quad_campaign_contract.py').read_bytes())==manifest['sources']['criteria']
  assert sha((ROOT/'tools/sputnik-load-twin.lua').read_bytes())==manifest['original_plant_sha256']
  for r in results:
   f=fixtures[r['fixture']];prefix='traces/'+r['fixture']+'/'+r['controller']+'/'
   event=next(e for e in csv.DictReader(io.StringIO(z.read(prefix+'events.csv').decode())) if e['case']==r['movement']);rows=[]
   if r['trace']:
    data=z.read('traces/'+r['trace']);assert sha(data)==r['trace_sha256'];rows=[{k:float(v) for k,v in x.items()} for x in csv.DictReader(io.StringIO(data.decode()))];count+=1
    assert len(rows)==r['frames']+1 and all(math.isfinite(v) for x in rows for v in x.values())
    assert all(0<=x['u'+str(i)]<=15 and x['u'+str(i)]%1==0 and 0<=x['rpm'+str(i)]<=256 for x in rows for i in range(1,5))
    for row in rows:
     t=row['t'];active=5<=t<10;forward=1 if active and r['movement'] in ('brake','forward-left') else 0;left=1 if active and r['movement']=='forward-left' else 0
     vertical=(1 if r['movement'] in ('climb','vertical-cycle') else -1 if r['movement']=='descend' else 0) if active else -1 if r['movement']=='vertical-cycle' and 15<=t<20 else 0
     assert (row['forward'],row['left'],row['vertical'])==(forward,left,vertical),'Movement protocol changed'
     assert row['true_mass']==f['mass'],'Payload mass leaked into native ship mass'
     assert all(abs(row['true_i'+axis]-v)<1e-7 for axis,v in zip(('x','y','z'),f['inertia']))
     assert 0<=row['rope_angle']<=180 and row['rope_stretch']>=0
     assert abs(sum(row[k]**2 for k in ('qw','qx','qy','qz'))-1)<1e-7
   score=evaluate_load(rows,event,r['movement'],60)
   for k in ('status','failures','reason','criteria','metrics'):assert r[k]==score[k],(r['fixture'],r['controller'],r['movement'],k)
 assert count==art['trace_count']==96
 pages=0;pdfs=0
 with zipfile.ZipFile(out/'native-load-plots.zip') as z:
  for name in z.namelist():
   if name.endswith('.pdf'):pages+=len(PdfReader(io.BytesIO(z.read(name))).pages);pdfs+=1
 assert pages==48 and pdfs==8
 print('Verified 96 native suspended-load classifications/traces, 8 PDFs/48 pages, command protocols, unchanged ship mass, 256 RPM, integer outputs and unchanged generic controller')
if __name__=='__main__':main()
