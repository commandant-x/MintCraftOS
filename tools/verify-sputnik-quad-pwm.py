#!/usr/bin/env python3
"""Recompute every fixed-source PWM result from archived native traces."""
import argparse,collections,csv,hashlib,importlib.util,io,json,zipfile
from pathlib import Path
from pypdf import PdfReader
from quad_campaign_contract import evaluate
spec=importlib.util.spec_from_file_location('diag',Path(__file__).with_name('analyze-sputnik-quad-ringing.py'));diag=importlib.util.module_from_spec(spec);spec.loader.exec_module(diag)
ROOT=Path(__file__).resolve().parent.parent
def sha(data):return hashlib.sha256(data).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--report',type=Path,required=True);a=p.parse_args();out=a.report
 manifest=json.loads((out/'manifest.json').read_text());results=json.loads((out/'results.json').read_text())['results'];art=json.loads((out/'artifacts.json').read_text())
 expected={(s['fixture']['id'],c,name) for s in manifest['states'] for c in ('baseline','fixed') for name in s['cases']}
 assert len(expected)==len(results)==82 and {(r['fixture'],r['controller'],r['movement']) for r in results}==expected
 assert all(g['source']==256 for s in manifest['states'] for g in s['fixture']['rotors'])
 assert all(s['fixture'].get('sourceFactor',1)==1 for s in manifest['states'])
 assert sha((ROOT/'platforms/sputnik/dist/mintcraft-autopilot-quad-fpv.lua').read_bytes())==manifest['sources']['fixed']
 for name,rec in art['archives'].items():
  file=out/name;assert file.stat().st_size==rec['bytes'] and sha(file.read_bytes())==rec['sha256']
  with zipfile.ZipFile(file) as z:assert z.testzip() is None
 traces=0
 with zipfile.ZipFile(out/'native-pwm-traces.zip') as z:
  for k,expected_sha in manifest['sources'].items():
   name='VerifySputnikLua.java' if k=='java_runner' else k+('.py' if k in ('criteria','diagnostics','runner') else '.csv' if k=='pressure' else '.lua')
   assert sha(z.read('frozen-sources/'+name))==expected_sha,k
  assert sha(z.read('frozen-sources/plant.lua'))==manifest['plant_sha256']
  for r in results:
   prefix='traces/'+r['fixture']+'/'+r['controller']+'/'
   event=next(e for e in csv.DictReader(io.StringIO(z.read(prefix+'events.csv').decode())) if e['case']==r['movement'])
   rows=[]
   if r['trace']:
    data=z.read('traces/'+r['trace']);assert sha(data)==r['trace_sha256'];rows=[{k:float(v) for k,v in x.items()} for x in csv.DictReader(io.StringIO(data.decode()))];traces+=1
    assert len(rows)==r['frames']+1
    angle=int(r['fixture'].rsplit('tilt',1)[1]);assert abs(rows[0]['tilt']-angle)<1e-5
    assert all(0<=x['u'+str(i)]<=15 and x['u'+str(i)]%1==0 and 0<=x['rpm'+str(i)]<=256 for x in rows for i in range(1,5))
   score=evaluate(rows,event,r['movement'],60)
   for k in ('status','failures','criteria','metrics','reason'):assert r[k]==score[k],(r['fixture'],r['controller'],r['movement'],k)
   assert diag.transient(rows,r['movement'])==r['transient']
 assert traces==art['trace_count']==80
 pages=0;pdfs=0
 with zipfile.ZipFile(out/'native-pwm-plots.zip') as z:
  for name in z.namelist():
   if name.endswith('.pdf'):pages+=len(PdfReader(io.BytesIO(z.read(name))).pages);pdfs+=1
 assert pages==82 and pdfs==12
 print('Verified 82 native classifications, 80 exact traces, fixed mechanical 256 RPM and integer outputs, 12 PDFs/82 pages, persistent settling metrics and unchanged source models/gains')
if __name__=='__main__':main()
