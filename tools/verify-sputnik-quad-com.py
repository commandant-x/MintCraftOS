#!/usr/bin/env python3
"""Recompute every COM score and independently check point-load tensors/frames."""
import argparse,csv,hashlib,io,json,math,zipfile
from pathlib import Path
from pypdf import PdfReader
from quad_com_contract import evaluate_com
ROOT=Path(__file__).resolve().parent.parent
def sha(data):return hashlib.sha256(data).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--report',type=Path,required=True);a=p.parse_args();out=a.report
 manifest=json.loads((out/'manifest.json').read_text());results=json.loads((out/'results.json').read_text())['results'];art=json.loads((out/'artifacts.json').read_text());fixtures={s['fixture']['id']:s['fixture'] for s in manifest['states']}
 expected={(s['fixture']['id'],c,name) for s in manifest['states'] for c in ('baseline','fixed') for name in s['cases']}
 assert len(expected)==len(results)==72 and {(r['fixture'],r['controller'],r['movement']) for r in results}==expected
 assert all(g['source']==256 for f in fixtures.values() for g in f['rotors'])
 assert sha((ROOT/'platforms/sputnik/dist/mintcraft-autopilot-quad-fpv.lua').read_bytes())==manifest['sources']['fixed']
 assert sha((ROOT/'platforms/sputnik/dist/mintcraft-autopilot-control.lua').read_bytes())=='f62be0b6c8615597f61518f218198dac66afd645daa89562344c7039dcec4092'
 for name,rec in art['archives'].items():
  file=out/name;assert file.stat().st_size==rec['bytes'] and sha(file.read_bytes())==rec['sha256']
  with zipfile.ZipFile(file) as z:assert z.testzip() is None
 count=0
 with zipfile.ZipFile(out/'native-com-traces.zip') as z:
  for k,expected_sha in manifest['sources'].items():
   name='VerifySputnikLua.java' if k=='java_runner' else k+('.py' if k in ('criteria','com_criteria','diagnostics','runner') else '.csv' if k=='pressure' else '.lua')
   assert sha(z.read('frozen-sources/'+name))==expected_sha,k
  assert sha(z.read('frozen-sources/plant.lua'))==manifest['plant_sha256']
  assert sha((ROOT/'tools/quad_com_contract.py').read_bytes())==manifest['sources']['com_criteria']
  assert sha((ROOT/'tools/quad_campaign_contract.py').read_bytes())==manifest['sources']['criteria']
  assert sha((ROOT/'tools/sputnik-com-twin.lua').read_bytes())==manifest['original_plant_sha256']
  for r in results:
   f=fixtures[r['fixture']];prefix='traces/'+r['fixture']+'/'+r['controller']+'/'
   event=next(e for e in csv.DictReader(io.StringIO(z.read(prefix+'events.csv').decode())) if e['case']==r['movement']);rows=[]
   if r['trace']:
    data=z.read('traces/'+r['trace']);assert sha(data)==r['trace_sha256'];rows=[{k:float(v) for k,v in x.items()} for x in csv.DictReader(io.StringIO(data.decode()))];count+=1
    assert len(rows)==r['frames']+1 and all(math.isfinite(v) for x in rows for v in x.values())
    assert all(0<=x['u'+str(i)]<=15 and x['u'+str(i)]%1==0 and 0<=x['rpm'+str(i)]<=256 for x in rows for i in range(1,5))
    for row in rows:
     active=r['movement']!='hover' and 5<=row['t']<10
     assert row['forward']==(1 if active else 0) and row['left']==(1 if active and r['movement']=='forward-left' else 0) and row['vertical']==0,'Missing/changed movement protocol'
     # Independently reconstruct every actual inertia tensor, including off-diagonals.
     load=f.get('initialLoad',{}).get('payload',dict(mass=0,position=[0,0,0]))
     for change in f['changes']:
      if change['at']<=row['t']+1e-7:load=change['payload']
     base=f['chassisMass'];total=base+load['mass'];center=[load['mass']*v/total for v in load['position']]
     tensor=[[f['chassisInertia'][i] if i==j else 0 for j in range(3)] for i in range(3)]
     for mass,position in [(base,[0,0,0]),(load['mass'],load['position'])]:
      d=[position[i]-center[i] for i in range(3)];norm=sum(v*v for v in d)
      for i in range(3):
       for j in range(3):tensor[i][j]+=mass*((norm if i==j else 0)-d[i]*d[j])
     actual=[row[k] for k in ('true_mass','true_com_x','true_com_y','true_com_z','true_ix','true_iy','true_iz','true_ixy','true_ixz','true_iyz')]
     wanted=[total,*center,tensor[0][0],tensor[1][1],tensor[2][2],tensor[0][1],tensor[0][2],tensor[1][2]]
     assert all(abs(x-y)<max(1e-5,abs(y)*1e-8) for x,y in zip(actual,wanted)),(r['fixture'],row['t'],'tensor')
     q=[row[k] for k in ('qw','qx','qy','qz')];assert abs(sum(v*v for v in q)-1)<1e-7
     # Quaternion rotation independently via matrix, not the twin's cross formula.
     w,x,y,zz=q;rotation=[[1-2*(y*y+zz*zz),2*(x*y-w*zz),2*(x*zz+w*y)],[2*(x*y+w*zz),1-2*(x*x+zz*zz),2*(y*zz-w*x)],[2*(x*zz-w*y),2*(y*zz+w*x),1-2*(x*x+y*y)]]
     offset=[sum(rotation[i][j]*center[j] for j in range(3)) for i in range(3)]
     for i,key in enumerate(('x','y','z')):assert abs(row['world_com_'+key]-row[key]-offset[i])<2e-5,(r['fixture'],row['t'],'frame')
   score=evaluate_com(rows,event,r['movement'],60,f)
   for k in ('status','historical','checks','episodes'):assert r[k]==score[k],(r['fixture'],r['controller'],r['movement'],k)
 assert count==art['trace_count']==72
 pages=0;pdfs=0
 with zipfile.ZipFile(out/'native-com-plots.zip') as z:
  for name in z.namelist():
   if name.endswith('.pdf'):pages+=len(PdfReader(io.BytesIO(z.read(name))).pages);pdfs+=1
 assert pages==36 and pdfs==12
 print('Verified 72 native COM classifications/traces, 12 PDFs/36 pages, independent actual tensors and body-origin transforms, 256 RPM, integer outputs and unchanged generic controller')
if __name__=='__main__':main()
