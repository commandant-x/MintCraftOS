#!/usr/bin/env python3
"""Native LuaJ point-load reconfiguration regression at a fixed 256 RPM source."""
import argparse,concurrent.futures,copy,csv,hashlib,importlib.util,json,math,os,subprocess,time,zipfile
from pathlib import Path
from quad_com_contract import fixtures_com,evaluate_com
spec=importlib.util.spec_from_file_location('runner',Path(__file__).with_name('run-sputnik-quad-campaign.py'));runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
spec=importlib.util.spec_from_file_location('diag',Path(__file__).with_name('analyze-sputnik-quad-ringing.py'));diag=importlib.util.module_from_spec(spec);spec.loader.exec_module(diag)
ROOT=Path(__file__).resolve().parent.parent
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--cosmonautics-jar',type=Path,required=True);p.add_argument('--java-home',type=Path,required=True);p.add_argument('--baseline',type=Path,required=True);p.add_argument('--work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--jobs',type=int,default=2);a=p.parse_args()
 assert 1<=a.jobs<=4
 out=a.output.resolve();work=a.work.resolve();out.mkdir(parents=True,exist_ok=True);work.mkdir(parents=True,exist_ok=True);assert not (work/'results').exists(),'Use fresh work directory'
 dist=ROOT/'platforms/sputnik/dist';manifest=json.loads((dist/'manifest.json').read_text());assert digest(a.cosmonautics_jar)==manifest['hostJarSha256']
 files={'fixed':dist/'mintcraft-autopilot-quad-fpv.lua','baseline':a.baseline.resolve(),'defaults':ROOT/'platforms/sputnik/src/vehicle_model.lua','pressure':ROOT/'platforms/sputnik/tests/fixtures/sable-pressure.csv','java_runner':ROOT/'tools/VerifySputnikLua.java','criteria':ROOT/'tools/quad_campaign_contract.py','com_criteria':ROOT/'tools/quad_com_contract.py','diagnostics':Path(__file__).with_name('analyze-sputnik-quad-ringing.py'),'runner':Path(__file__).resolve()}
 snap=work/'snapshots';snap.mkdir();frozen={}
 for name,path in files.items():
  target=snap/('VerifySputnikLua.java' if name=='java_runner' else name+path.suffix);target.write_bytes(path.read_bytes());frozen[name]=target
 plant=snap/'plant.lua';plant.write_bytes((ROOT/'tools/sputnik-com-twin.lua').read_bytes())
 runtime=work/'runtime.jar'
 with zipfile.ZipFile(a.cosmonautics_jar) as z,zipfile.ZipFile(runtime,'w') as dst:
  for name in z.namelist():
   if name.startswith('dev/devce/rocketnautics/shaded/luaj/') and name.endswith('.class'):dst.writestr(name,z.read(name))
 subprocess.run([str(a.java_home/'bin/javac'),'-cp',str(runtime),'-d',str(work),str(frozen['java_runner'])],cwd=ROOT,check=True)
 states=[dict(fixture=f,cases=['hover','brake','forward-left']) for f in fixtures_com()];jobs=[(s['fixture'],s['cases'],c) for s in states for c in ('baseline','fixed')]
 metadata=dict(schema=1,version=manifest['version'],host_sha256=manifest['hostJarSha256'],sources={k:digest(v) for k,v in frozen.items()},plant_sha256=digest(plant),original_plant_sha256=digest(ROOT/'tools/sputnik-com-twin.lua'),states=states,scope='Fixed 256 RPM, native LuaJ, independent 6DOF plant. No Minecraft world qualification.',bands=diag.BANDS,seconds=60,control_hz=20,physics_hz=200)
 (out/'manifest.json').write_text(json.dumps(metadata,indent=2)+'\n')
 jvm=[str(a.java_home/'bin/java'),'-XX:ActiveProcessorCount=1','-XX:+UseSerialGC','-Xmx512m','-cp',str(work)+os.pathsep+str(runtime),'VerifySputnikLua']
 def run(job):
  f,cases,controller=job;folder=work/'results'/f['id']/controller;folder.mkdir(parents=True)
  cfg=dict(fixture=f,seconds=60,cases=cases,controller=str(frozen[controller]),defaults=str(frozen['defaults']),pressure=str(frozen['pressure']),output=str(folder),tilt=20)
  boot=folder/'bootstrap.lua';boot.write_text('MINTCRAFT_CAMPAIGN='+runner.lua(cfg)+'\n')
  with (folder/'runtime.log').open('w') as log:subprocess.run(jvm+[str(boot),str(plant)],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=900)
  values=[]
  for event in csv.DictReader((folder/'events.csv').open()):
   assert event['status'] in ('COMPLETE','FAULT','REFUSED'),event
   path=folder/(event['case']+'.csv');rows=runner.read_trace(path)
   if not rows:assert event['status']=='REFUSED','Missing physical trace must not become a pass'
   values.append(dict(fixture=f['id'],controller=controller,movement=event['case'],**evaluate_com(rows,event,event['case'],60,f),transient=diag.transient(rows,event['case']),frames=int(float(event['frames'])),trace=str(path.relative_to(work/'results')) if rows else None,trace_sha256=digest(path) if rows else None))
  print(f['id'],controller,sum(v['status']=='PASS' for v in values),'/',len(values),flush=True);return values
 results=[];start=time.monotonic()
 with concurrent.futures.ThreadPoolExecutor(max_workers=a.jobs) as pool:
  for values in pool.map(run,jobs):results.extend(values);(out/'results.json').write_text(json.dumps(dict(results=results,wall_seconds=time.monotonic()-start),indent=2)+'\n')
 assert all(digest(files[k])==digest(v) for k,v in frozen.items()),'Sources changed during execution'
 assert len(results)==sum(len(s['cases'])*2 for s in states)
 print('Native COM regression complete:',len(results),'cases',flush=True)
if __name__=='__main__':main()
