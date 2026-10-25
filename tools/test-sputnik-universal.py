#!/usr/bin/env python3
"""Run exact shipped universal Lua in audited Cosmonautics LuaJ against independent 6DOF mechanics."""
import argparse, csv, fcntl, hashlib, json, math, os, shutil, subprocess, tempfile, zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--cosmonautics-jar',type=Path,required=True)
p.add_argument('--java-home',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--profiles',default='1,2,3,4,5')
p.add_argument('--cases',default='hover,altitude,forward,reverse,turn,mass,calibration,mission,mission_straight,cruise')
p.add_argument('--mass',type=float,default=32)
p.add_argument('--inertia-scale',type=float,default=1)
p.add_argument('--delay',type=int,default=1)
p.add_argument('--noise',type=float,default=0)
p.add_argument('--com-x',type=float,default=0)
p.add_argument('--rotor-factor',type=float,default=1)
p.add_argument('--assert-all',action='store_true')
a=p.parse_args();a.output=a.output.resolve();a.output.mkdir(parents=True,exist_ok=True)
lock_path=Path(tempfile.gettempdir())/('mintcraft-universal-'+hashlib.sha256(str(a.output).encode()).hexdigest()[:20]+'.lock')
lock=lock_path.open('a')
try: fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
except BlockingIOError: p.error('This output directory already has a running benchmark')
digest=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
m=json.loads((ROOT/'platforms/sputnik/dist/manifest.json').read_text())
assert digest(a.cosmonautics_jar)==m['hostJarSha256']
for name,record in m['artifacts'].items(): assert digest(ROOT/'platforms/sputnik/dist'/name)==record['sha256'],name
profiles=[int(x) for x in a.profiles.split(',')];assert all(1<=x<=5 for x in profiles)
controller=ROOT/'platforms/sputnik/dist/mintcraft-autopilot-control.lua'
controller_bytes=controller.read_bytes();controller_digest=hashlib.sha256(controller_bytes).hexdigest()
plant_bytes=(ROOT/'tools/sputnik-universal-twin.lua').read_bytes();plant_digest=hashlib.sha256(plant_bytes).hexdigest()
defaults_bytes=(ROOT/'platforms/sputnik/src/vehicle_model.lua').read_bytes();defaults_digest=hashlib.sha256(defaults_bytes).hexdigest()
fixture=dict(mass=a.mass,inertiaScale=a.inertia_scale,delay=a.delay,noise=a.noise,comX=a.com_x,rotorFactor=a.rotor_factor)
assert all(math.isfinite(v) for v in fixture.values())
assert a.mass>0 and a.inertia_scale>0 and 1<=a.delay<=6 and a.noise>=0 and a.rotor_factor>=0
with tempfile.TemporaryDirectory(prefix='sputnik-universal-') as temp:
 folder=Path(temp);runtime=folder/'runtime.jar';work=folder/'results';work.mkdir()
 with zipfile.ZipFile(a.cosmonautics_jar) as source,zipfile.ZipFile(runtime,'w') as target:
  for name in source.namelist():
   if name.startswith('dev/devce/rocketnautics/shaded/luaj/') and name.endswith('.class'):target.writestr(name,source.read(name))
 subprocess.run([str(a.java_home/'bin/javac'),'-cp',str(runtime),'-d',str(folder),str(ROOT/'tools/VerifySputnikLua.java')],check=True,cwd=ROOT)
 snapshot=folder/'controller.lua';snapshot.write_bytes(controller_bytes)
 plant=folder/'plant.lua';plant.write_bytes(plant_bytes)
 defaults=folder/'defaults.lua';defaults.write_bytes(defaults_bytes)
 bootstrap=folder/'bootstrap.lua';bootstrap.write_text('MINTCRAFT_UNIVERSAL_DEFAULTS='+json.dumps(str(defaults))+'\n'+'MINTCRAFT_UNIVERSAL_CONTROLLER='+json.dumps(str(snapshot))+'\n'+'MINTCRAFT_UNIVERSAL_OUTPUT='+json.dumps(str(work))+'\nMINTCRAFT_UNIVERSAL_PROFILES={'+','.join(map(str,profiles))+'}\nMINTCRAFT_UNIVERSAL_CASES={'+','.join(json.dumps(x) for x in a.cases.split(','))+'}\nMINTCRAFT_UNIVERSAL_FIXTURE={'+','.join(k+'='+str(v) for k,v in fixture.items())+'}\n')
 try:
  with (work/'runtime.log').open('w') as log:
   subprocess.run([str(a.java_home/'bin/java'),'-Xmx768m','-cp',str(folder)+os.pathsep+str(runtime),'VerifySputnikLua',str(bootstrap),str(plant)],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
 finally:
  for name in ('runtime.log','summary.csv'):
   if (work/name).exists():
    destination=a.output/('.'+name+'.tmp');shutil.copyfile(work/name,destination);os.replace(destination,a.output/name)
raw=(a.output/'summary.csv').read_bytes();assert b'\x00' not in raw,'Torn benchmark CSV: reject this run'
rows=list(csv.DictReader(raw.decode().splitlines()));assert len(rows)==len(profiles)*len(a.cases.split(',')),'Incomplete benchmark CSV'
assert {(r['profile'],r['scenario']) for r in rows}=={(str(v),case) for v in profiles for case in a.cases.split(',')}
assert all(r['status'] in ('PASS','FAIL','REFUSED') and None not in r for r in rows)
passed=sum(r['status']=='PASS' for r in rows)
metadata=dict(version=m['version'],base_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
 controller_sha256=controller_digest,plant_sha256=plant_digest,defaults_sha256=defaults_digest,host_sha256=digest(a.cosmonautics_jar),
 csv_sha256=hashlib.sha256(raw).hexdigest(),scope='Independent synthetic 6DOF plant in actual LuaJ; not a measured Minecraft replica or world qualification',fixture=fixture,passed=passed,total=len(rows),scenarios=rows,
 assumptions=['Overworld Sable pressure Java oracle sampled every metre','20 Hz controller and motor spool; 200 Hz rigid body','Linear translation drag 0.2/s and rotation drag 0.05/s','Local linear lift/yaw gains and rudder model are synthetic declared fixtures, not measurements of user hardware','Diagonal inertias 250/400/230 times configured scale','Mixed rotors: sails 8/12/16/20, x=-4/+2, z=+5/-5; forces start at known equilibrium','No collisions, terrain, stress networks, joints, gyroscopic propeller torques or ground effect'],
 criteria=dict(final_altitude_error_lt=1,maximum_tilt_lt=25,final_speed_lt=.3,last_10s_speed_rms_lt=.35,movement_extent_gt=.2,turn_yaw_gt=3,quad_turn_lateral_extent_gt=.05,calibration_complete_required=True,mission_complete_required=True))
(a.output/'summary.json').write_text(json.dumps(metadata,indent=2,ensure_ascii=False)+'\n')
text=['# Sputnik '+m['version']+' — banc universel','',f'**{passed}/{len(rows)} scénarios réussis. Plante synthétique indépendante, LuaJ réel ; aucun essai dans le monde Minecraft.**','',
 'Les échecs sont conservés. Un succès du maintien ne qualifie pas une mission ou un axe absent. Les excursions transitoires sont affichées séparément. Les hypothèses complètes et empreintes sont dans `summary.json`.','',
 '| Architecture | Scénario | Résultat | Erreur finale hauteur m | Excursion hauteur max m | Inclinaison max ° | Vitesse finale m/s | RMS vitesse 10 s |','| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |']
names={'1':'Quad petites','2':'Ballon/gouverne','3':'Venator','4':'Hélicoptère','5':'Quad modulaire hétérogène'}
for r in rows:text.append('| '+names[r['profile']]+' | '+r['scenario']+' | '+r['status']+' | '+' | '.join(f'{float(r[k]):.4f}' for k in ['altitude_error','max_error','max_tilt','final_speed','tail_speed_rms'])+' |')
(a.output/'README.md').write_text('\n'.join(text)+'\n')
print(f'Universal LuaJ: {passed}/{len(rows)}; reports {a.output}')
if a.assert_all: assert passed==len(rows),'Reference scenario failure; inspect published failures'
