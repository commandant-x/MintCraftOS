#!/usr/bin/env python3
"""Audit every published campaign classification against immutable complete native traces."""
import argparse,collections,csv,hashlib,json,math,zipfile
from pathlib import Path
from pypdf import PdfReader
from quad_campaign_contract import evaluate
import io
ROOT=Path(__file__).resolve().parent.parent
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def finite_tree(v):
 if isinstance(v,float):assert math.isfinite(v),'Nonfinite report value'
 elif isinstance(v,dict):
  for x in v.values():finite_tree(x)
 elif isinstance(v,list):
  for x in v:finite_tree(x)
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--report',type=Path,required=True);p.add_argument('--work',type=Path,required=True);a=p.parse_args()
 report=a.report;work=a.work;m=json.loads((report/'campaign.json').read_text());r=json.loads((report/'results.json').read_text());artifacts=json.loads((report/'artifacts.json').read_text())
 finite_tree(m);finite_tree(r)
 mapping={'plant':'tools/sputnik-quad-campaign.lua','criteria':'tools/quad_campaign_contract.py','runner':'tools/run-sputnik-quad-campaign.py','java_runner':'tools/VerifySputnikLua.java','defaults':'platforms/sputnik/src/vehicle_model.lua','pressure':'platforms/sputnik/tests/fixtures/sable-pressure.csv','controller_standard':'platforms/sputnik/dist/mintcraft-autopilot-control.lua','controller_fpv':'platforms/sputnik/dist/mintcraft-autopilot-quad-fpv.lua'}
 for k,path in mapping.items():assert digest(ROOT/path)==m['sources'][k],k
 expected={(f['id'],c,case) for f in m['fixtures'] for c in m['controllers'] for case in m['cases']}
 assert len(r['results'])==len(expected)==r['total'] and {(x['fixture'],x['controller'],x['movement']) for x in r['results']}==expected
 assert dict(collections.Counter(x['status'] for x in r['results']))==r['counts']
 assert len(list(csv.DictReader((report/'results.csv').open())))==r['total']
 actual_traces=0;trace_hashes={}
 for item in r['results']:
  path=work/'results'/item['fixture']/item['controller'];events={e['case']:e for e in csv.DictReader((path/'events.csv').open())};event=events[item['movement']]
  rows=[]
  if item['trace']:
   file=work/'results'/item['trace'];assert digest(file)==item['trace_sha256'];actual_traces+=1;trace_hashes['traces/'+item['trace']]=item['trace_sha256']
   rows=[{k:float(v) for k,v in x.items()} for x in csv.DictReader(file.open())]
   assert len(rows)==item['frames']+1
  score=evaluate(rows,event,item['movement'],m['seconds'])
  for k in ('status','failures','reason','criteria','metrics'):assert score[k]==item[k],(item['fixture'],item['controller'],item['movement'],k)
  if item['status']=='PASS':assert item['criteria'] and all(item['criteria'].values())
 assert actual_traces==artifacts['trace_count']
 pages=0;pdfs=0;archived_traces=0
 for name,rec in artifacts['archives'].items():
  path=report/name;assert path.stat().st_size==rec['bytes'] and digest(path)==rec['sha256'];assert path.stat().st_size<95000000
  with zipfile.ZipFile(path) as z:
   assert z.testzip() is None
   for n in z.namelist():
    if n in trace_hashes:assert hashlib.sha256(z.read(n)).hexdigest()==trace_hashes[n];archived_traces+=1
    if n.endswith('.pdf'):
     fixture,controller=Path(n).stem.rsplit('-',1);items=[x for x in r['results'] if x['fixture']==fixture and x['controller']==controller]
     assert items;expected_pages=sum(x['trace'] is not None for x in items) or 1
     count=len(PdfReader(io.BytesIO(z.read(n))).pages);assert count==expected_pages,(n,count,expected_pages);pages+=count;pdfs+=1
 assert archived_traces==actual_traces and pdfs==len(m['fixtures'])*len(m['controllers'])
 assert r['solver_steps']==10*sum(x['frames'] for x in r['results'])
 assert (ROOT/'platforms/sputnik/dist/mintcraft-sputnik-0.3.1.zip').stat().st_size<1000000
 print(f"Verified {r['total']} classifications from {actual_traces} exact traces, {pdfs} PDFs / {pages} pages, archive CRC/SHA-256 and unchanged <1MB flight package")
if __name__=='__main__':main()
