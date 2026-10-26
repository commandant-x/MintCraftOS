#!/usr/bin/env python3
"""Repeat representative campaign cases at 400 Hz to expose timestep-sensitive conclusions."""
import argparse,csv,hashlib,importlib.util,json,os,subprocess,zipfile
from pathlib import Path
from quad_campaign_contract import evaluate
ROOT=Path(__file__).resolve().parent.parent
spec=importlib.util.spec_from_file_location('campaign_runner',ROOT/'tools/run-sputnik-quad-campaign.py');runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
lua,read_trace=runner.lua,runner.read_trace
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--java-home',type=Path,required=True);a=p.parse_args()
 work=a.work.resolve();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
 campaign=json.loads((out.parent/'campaign.json').read_text())
 if (out.parent/'results.json').exists():final=json.loads((out.parent/'results.json').read_text())
 else:
  # Reference workers are immutable and complete even while other geometries run.
  rr=[]
  for controller in campaign['controllers']:
   folder=work/'results/reference'/controller;stamp=json.loads((folder/'done.json').read_text())
   for name,sha in stamp['hashes'].items():assert digest(folder/name)==sha
   for event in csv.DictReader((folder/'events.csv').open()):
    path=folder/(event['case']+'.csv');score=evaluate(read_trace(path),event,event['case'],campaign['seconds'])
    rr.append(dict(fixture='reference',controller=controller,movement=event['case'],**score))
  final=dict(results=rr)

 fixture=next(f for f in campaign['fixtures'] if f['id']=='reference');cases=['hover','forward-left','turn-left','load-swing']
 source=(work/'snapshots/plant.lua').read_text();assert source.count('for _=1,10 do')==1 and source.count('local dt=.005;')==1
 refined=source.replace('for _=1,10 do','for _=1,20 do').replace('local dt=.005;','local dt=.0025;').replace('solverSteps=solverSteps+10','solverSteps=solverSteps+20')
 plant=work/'convergence-400.lua';plant.write_text(refined)
 jvm=[str(a.java_home/'bin/java'),'-XX:ActiveProcessorCount=1','-XX:+UseSerialGC','-Xmx512m','-cp',str(work)+os.pathsep+str(work/'runtime.jar'),'VerifySputnikLua']
 results=[]
 for controller in campaign['controllers']:
  folder=work/'convergence-400'/controller;folder.mkdir(parents=True,exist_ok=True)
  config=dict(fixture=fixture,seconds=campaign['seconds'],cases=cases,controller=str(work/'snapshots'/('controller_'+controller+'.lua')),defaults=str(work/'snapshots/defaults.lua'),pressure=str(work/'snapshots/pressure.csv'),output=str(folder))
  boot=folder/'bootstrap.lua';boot.write_text('MINTCRAFT_CAMPAIGN='+lua(config)+'\n')
  with (folder/'runtime.log').open('w') as log:subprocess.run(jvm+[str(boot),str(plant)],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=600)
  for event in csv.DictReader((folder/'events.csv').open()):
   assert event['status'] in ('COMPLETE','FAULT','REFUSED')
   name=event['case'];path=folder/(name+'.csv');trace=read_trace(path);score=evaluate(trace,event,name,campaign['seconds'])
   original=next(r for r in final['results'] if r['fixture']=='reference' and r['controller']==controller and r['movement']==name)
   keys=['transient_height_peak','tail_height_span','tail_speed_rms','active_attitude_rms']
   delta={k:score['metrics'][k]-original['metrics'][k] for k in keys if score['metrics'].get(k) is not None and original['metrics'].get(k) is not None}
   results.append(dict(controller=controller,movement=name,status_200=original['status'],status_400=score['status'],classification_agrees=original['status']==score['status'],failures_200=original['failures'],failures_400=score['failures'],metrics_400=score['metrics'],metric_delta_400_minus_200=delta,trace_sha256=digest(path)))
  print('Convergence complete:',controller,flush=True)
 metadata=dict(schema=1,base_plant_sha256=digest(work/'snapshots/plant.lua'),refined_plant_sha256=digest(plant),control_hz=20,physics_hz=[200,400],cases=results,scope='Timestep sensitivity of four representative reference motions; not proof of physical fidelity or convergence for every fixture')
 (out/'summary.json').write_text(json.dumps(metadata,indent=2)+'\n')
 lines=['# Sensibilité au pas de mécanique : 200 / 400 Hz','', 'Le contrôleur reste à 20 Hz ; seuls le nombre de sous-pas et leur durée changent. Les échecs du contrôleur ne deviennent pas des succès par définition. Les variations sont publiées même si elles changent une classification.','', '| Contrôleur | Mouvement | 200 Hz | 400 Hz | Même classification | Écart pic hauteur m |','| --- | --- | --- | --- | --- | ---: |']
 for r in results:lines.append('| '+r['controller']+' | '+r['movement']+' | '+r['status_200']+' | '+r['status_400']+' | '+str(r['classification_agrees'])+' | '+str(round(r['metric_delta_400_minus_200'].get('transient_height_peak',0),5))+' |')
 lines+=['','Les conclusions sensibles au pas doivent être considérées comme non robustes. Cette vérification ne couvre pas tous les montages ni le solveur Minecraft. Les traces et la variante exacte du banc sont dans `convergence-traces.zip`.']
 (out/'README.md').write_text('\n'.join(lines)+'\n')
 with zipfile.ZipFile(out/'convergence-traces.zip','w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  z.write(plant,'plant-400hz.lua')
  for path in sorted((work/'convergence-400').rglob('*')):
   if path.is_file() and path.name!='bootstrap.lua':z.write(path,path.relative_to(work/'convergence-400'))
 print('Classification agreement:',sum(r['classification_agrees'] for r in results),'/',len(results))
if __name__=='__main__':main()
