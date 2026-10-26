#!/usr/bin/env python3
"""Reproducible architecture × movement × controller campaign in audited native LuaJ."""
import argparse,concurrent.futures,csv,fcntl,hashlib,json,math,os,shutil,subprocess,tempfile,time,zipfile
from pathlib import Path
from quad_campaign_contract import SCHEMA,MOVEMENTS,CRITERIA,fixtures,evaluate
ROOT=Path(__file__).resolve().parent.parent

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def lua(value):
 if value is None:return 'nil'
 if isinstance(value,bool):return str(value).lower()
 if isinstance(value,(float,int)):
  assert math.isfinite(value);return repr(value)
 if isinstance(value,str):return json.dumps(value,ensure_ascii=True)
 if isinstance(value,list):return '{'+','.join(lua(v) for v in value)+'}'
 if isinstance(value,dict):return '{'+','.join('['+lua(k)+']='+lua(v) for k,v in value.items())+'}'
 raise TypeError(type(value))

def read_trace(path):
 if not path.exists():return []
 rows=[]
 for row in csv.DictReader(path.open()):
  assert None not in row and None not in row.values(),'Torn trace'
  r={k:float(v) for k,v in row.items()}
  assert all(math.isfinite(v) for v in r.values()),'Nonfinite trace'
  assert not rows or r['t']>rows[-1]['t'],'Nonmonotone trace time'
  assert all(0<=r['u'+str(i)]<=15 and r['u'+str(i)].is_integer() for i in range(1,5)),'Noninteger actuation'
  rows.append(r)
 return rows

def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--cosmonautics-jar',type=Path,required=True);p.add_argument('--java-home',type=Path,required=True)
 p.add_argument('--output',type=Path,required=True);p.add_argument('--work',type=Path,required=True)
 p.add_argument('--tilt',type=float,default=20);p.add_argument('--jobs',type=int,default=4);p.add_argument('--seconds',type=int,default=60)
 p.add_argument('--fixtures',default='all');p.add_argument('--cases',default='all');p.add_argument('--controllers',default='standard,fpv')
 p.add_argument('--resume',action='store_true');a=p.parse_args()
 assert 1<=a.jobs<=4 and a.seconds>=40
 a.output=a.output.resolve();a.work=a.work.resolve();a.output.mkdir(parents=True,exist_ok=True);a.work.mkdir(parents=True,exist_ok=True)
 lock=(a.work/'run.lock').open('a');fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
 m=json.loads((ROOT/'platforms/sputnik/dist/manifest.json').read_text())
 assert digest(a.cosmonautics_jar)==m['hostJarSha256'],'Unaudited interpreter'
 dist=ROOT/'platforms/sputnik/dist'
 controllers={'standard':dist/'mintcraft-autopilot-control.lua','fpv':dist/'mintcraft-autopilot-quad-fpv.lua'}
 selected=a.controllers.split(',');assert 0<a.tilt<=45 and ('standard' not in selected or a.tilt<=20)
 assert len(set(selected))==len(selected) and set(selected)<=set(controllers)
 fs=fixtures();wanted=set(a.fixtures.split(','))
 if a.fixtures!='all':assert wanted<=set(f['id'] for f in fs);fs=[f for f in fs if f['id'] in wanted]
 cases=list(MOVEMENTS) if a.cases=='all' else a.cases.split(',');assert len(set(cases))==len(cases) and set(cases)<=set(MOVEMENTS)
 sources={'plant':ROOT/'tools/sputnik-quad-campaign.lua','criteria':ROOT/'tools/quad_campaign_contract.py','runner':Path(__file__).resolve(),'java_runner':ROOT/'tools/VerifySputnikLua.java','defaults':ROOT/'platforms/sputnik/src/vehicle_model.lua','pressure':ROOT/'platforms/sputnik/tests/fixtures/sable-pressure.csv'}
 for name in selected:sources['controller_'+name]=controllers[name]
 for name in selected:
  file=controllers[name];assert digest(file)==m['artifacts'][file.name]['sha256'],'Controller differs from distribution'
 record=dict(schema=SCHEMA,distribution_version=m['version'],base_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),host_sha256=digest(a.cosmonautics_jar),sources={k:digest(v) for k,v in sources.items()},seconds=a.seconds,control_hz=20,physics_hz=200,tilt_degrees=a.tilt,climb_mps=4,cases=cases,controllers=selected,fixtures=fs,criteria=CRITERIA,protocols={k:MOVEMENTS[k] for k in cases},scope='Synthetic rigid body and unilateral cable; native LuaJ. No Minecraft world qualification.',assumptions=['No ground/contacts, collision mesh, stress network, propeller gyroscopic torque or faithful Minecraft joint solver','Actual full inertia and physical disturbance parameters are independent of controller estimator; API exposes only inertia diagonal','Pressure oracle from audited Sable; actual pressure factors/wind/spool/delays are declared fixture disturbances','Tilt is recorded explicitly; generic graph is limited to 20deg, specialised quad accepts up to 45deg; climb demand 4m/s','Four fixed upward propellers: trajectory turns are measured, nose yaw is not a controlled criterion','Refusal remains REFUSED and never becomes a successful movement; all missing/incomplete traces fail'])
 manifest_path=a.output/'campaign.json'
 if a.resume:
  assert manifest_path.exists() and json.loads(manifest_path.read_text())==record,'Resume requires exactly the same frozen inputs/criteria'
 else:
  assert not (a.work/'results').exists(),'Use a fresh work directory or exact --resume'
 manifest_path.write_text(json.dumps(record,indent=2,ensure_ascii=False)+'\n')
 snap=a.work/'snapshots';snap.mkdir(exist_ok=True)
 frozen={}
 for name,path in sources.items():
  target=snap/('VerifySputnikLua.java' if name=='java_runner' else name+path.suffix);data=path.read_bytes()
  if target.exists():assert target.read_bytes()==data,'Snapshot was modified'
  else:target.write_bytes(data);target.chmod(0o444)
  frozen[name]=target
 runtime=a.work/'runtime.jar'
 with zipfile.ZipFile(a.cosmonautics_jar) as z,zipfile.ZipFile(runtime,'w') as out:
  for n in z.namelist():
   if n.startswith('dev/devce/rocketnautics/shaded/luaj/') and n.endswith('.class'):out.writestr(n,z.read(n))
 javac=str(a.java_home/'bin/javac');java=str(a.java_home/'bin/java')
 subprocess.run([javac,'-cp',str(runtime),'-d',str(a.work),str(frozen['java_runner'])],cwd=ROOT,check=True)
 # javac requires a public class filename; snapshot has the canonical name below.
 classpath=str(a.work)+os.pathsep+str(runtime)
 jvm=[java,'-XX:ActiveProcessorCount=1','-XX:+UseSerialGC','-Xmx512m','-cp',classpath,'VerifySputnikLua']
 # Independent tensor/rotation tests in the actual interpreter, before a costly run.
 maths=a.work/'maths.lua';maths.write_text('MINTCRAFT_CAMPAIGN_MATH_TEST=true\nlocal f=assert(io.open('+lua(str(frozen['plant']))+'));local text=f:read("*a");f:close();local M=assert(load(text))()\nlocal tensor={{250,45,-30},{45,400,40},{-30,40,230}};local v={2,-3,4};local r=M.mv(M.inverse(tensor),M.mv(tensor,v));for i=1,3 do assert(math.abs(r[i]-v[i])<1e-10) end\nassert(not pcall(M.inverse,{{1,2,0},{2,1,0},{0,0,1}}))\nlocal q={math.sqrt(.5),0,math.sqrt(.5),0};local r=M.rotate(q,{0,0,1});assert(math.abs(r[1]-1)<1e-12 and math.abs(r[3])<1e-12)\nfor _,v in ipairs({0,1,-1,80.0000001,math.pi,-1e-9,999999999.9,1e-30}) do local r=assert(tonumber(M.csv(v)),"Invalid trace encoding");assert(math.abs(r-v)<=6e-9*math.max(1e-30,math.abs(v))) end\nprint("Independent coupled inertia inversion, nonphysical tensor rejection, quaternion handedness and trace precision passed")\n')
 subprocess.run(jvm+[str(maths)],cwd=ROOT,check=True)
 jobs=[(f,c) for f in fs for c in selected];start=time.monotonic();results=[];completed=0
 progress=a.output/'progress.json'
 def run(job):
  f,c=job;folder=a.work/'results'/f['id']/c;folder.mkdir(parents=True,exist_ok=True)
  stamp=folder/'done.json'
  if not (a.resume and stamp.exists()):
   worker_start=time.monotonic()
   config=dict(fixture=f,tilt=a.tilt,seconds=a.seconds,cases=cases,controller=str(frozen['controller_'+c]),defaults=str(frozen['defaults']),pressure=str(frozen['pressure']),output=str(folder))
   boot=folder/'bootstrap.lua';boot.write_text('MINTCRAFT_CAMPAIGN='+lua(config)+'\n')
   with (folder/'runtime.log').open('w') as log:
    subprocess.run(jvm+[str(boot),str(frozen['plant'])],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=900)
   ev=list(csv.DictReader((folder/'events.csv').open()));assert len(ev)==len(cases) and {e['case'] for e in ev}==set(cases)
   assert all(e['status'] in ('COMPLETE','FAULT','REFUSED') for e in ev),'Controller or benchmark runtime error: inspect runtime.log'
   stamp.write_text(json.dumps(dict(wall_seconds=time.monotonic()-worker_start,hashes={p.name:digest(p) for p in sorted(folder.glob('*.csv'))})))
  hashes=json.loads(stamp.read_text())['hashes'];assert all(digest(folder/n)==h for n,h in hashes.items()),'Result changed after completion'
  out=[]
  for event in csv.DictReader((folder/'events.csv').open()):
   name=event['case'];path=folder/(name+'.csv');rows=read_trace(path);score=evaluate(rows,event,name,a.seconds)
   out.append(dict(fixture=f['id'],controller=c,movement=name,**score,worker_wall_seconds=json.loads(stamp.read_text())['wall_seconds'],frames=int(float(event['frames'])),simulated_seconds=float(event['simulated_seconds']),solver_steps=int(float(event['solver_steps'])),trace_sha256=digest(path) if path.exists() else None,trace=str(path.relative_to(a.work/'results')) if path.exists() else None))
  return out
 with concurrent.futures.ThreadPoolExecutor(max_workers=a.jobs) as pool:
  futures={pool.submit(run,j):j for j in jobs}
  for future in concurrent.futures.as_completed(futures):
   result=future.result();results.extend(result);completed+=1
   counts={s:sum(r['status']==s for r in results) for s in ('PASS','FAIL','REFUSED')}
   tmp=progress.with_suffix('.tmp');tmp.write_text(json.dumps(dict(completed_jobs=completed,total_jobs=len(jobs),counts=counts,wall_seconds=time.monotonic()-start)));os.replace(tmp,progress)
   f,c=futures[future];print(f"{completed}/{len(jobs)} {f['id']}/{c}: "+str({s:sum(r['status']==s for r in result) for s in counts}),flush=True)
 results.sort(key=lambda r:(r['fixture'],r['controller'],cases.index(r['movement'])))
 final=dict(wall_seconds=time.monotonic()-start,total=len(results),counts={s:sum(r['status']==s for r in results) for s in ('PASS','FAIL','REFUSED')},simulated_seconds=sum(r['simulated_seconds'] for r in results),solver_steps=sum(r['solver_steps'] for r in results),results=results)
 (a.output/'results.json').write_text(json.dumps(final,indent=2,ensure_ascii=False)+'\n')
 metric_keys=sorted({k for r in results for k in r['metrics']})
 with (a.output/'results.csv').open('w') as out:
  writer=csv.DictWriter(out,fieldnames=['fixture','controller','movement','status','failures','reason','frames','simulated_seconds','solver_steps','trace_sha256']+metric_keys);writer.writeheader()
  for r in results:writer.writerow({**{k:r[k] for k in ('fixture','controller','movement','status','reason','frames','simulated_seconds','solver_steps','trace_sha256')},'failures':' | '.join(r['failures']),**r['metrics']})
 assert all(digest(sources[k])==v for k,v in record['sources'].items()),'Source changed during campaign: results remain snapshots, rerun before publication'
 print('Campaign complete:',final['counts'],'simulated hours:',final['simulated_seconds']/3600,'solver steps:',final['solver_steps'],flush=True)

if __name__=='__main__':main()
