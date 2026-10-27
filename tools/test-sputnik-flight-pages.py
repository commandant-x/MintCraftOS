#!/usr/bin/env python3
"""Cross-language evidence export integrity: corruption and missing pages must fail."""
import importlib.util,tempfile,copy
from pathlib import Path
spec=importlib.util.spec_from_file_location('replay',Path(__file__).with_name('replay-sputnik-flight.py'));r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)

def test(paths):
 log=r.read_pages(paths);report=r.analyze(log);assert report['frames']>20 and report['stationary_intervals'] and not report['qualified'] and not report['hardware_ack']
 with tempfile.TemporaryDirectory(prefix='flight-pages-') as directory:
  out=Path(directory)/'page.txt';original=Path(paths[0]).read_text()
  for content in [original.replace('MCF1,','MCF1,NaN,',1),original+'\nE,1,FAULT,forged',original.replace('MCLOG1;','MCLOG9;',1)]:
   out.write_text(content)
   try:r.read_pages([out]);raise AssertionError('Corrupted evidence accepted')
   except ValueError:pass
  try:r.read_pages([paths[0],paths[0]]);raise AssertionError('Duplicate page accepted')
  except ValueError:pass
  # Split exactly the same payload into two real pages and verify order handling.
  first=original.rstrip('\n').split('\n',1);header=first[0].split(';');body=first[1];cut=body.find('\n',len(body)//2);chunks=[body[:cut],body[cut+1:]];header[4]='2'
  pages=[]
  for i,chunk in enumerate(chunks,1):
   h=header.copy();h[3]=str(i);p=Path(directory)/('split'+str(i)+'.txt');p.write_text(';'.join(h)+'\n'+chunk);pages.append(p)
  assert r.read_pages(list(reversed(pages)))['checksum']==log['checksum']
  try:r.read_pages(pages[:1]);raise AssertionError('Missing page accepted')
  except ValueError:pass
 print('Cross-runtime log: checksums, mixed/duplicate/missing/corrupt page rejection and ordered observed stability passed')
if __name__=='__main__':
 import sys;test([Path(p) for p in sys.argv[1:]])
