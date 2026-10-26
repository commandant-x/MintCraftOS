#!/usr/bin/env python3
"""Run exact shipped quad FPV Lua in audited LuaJ against independent 6DOF and cable mechanics."""
import argparse, csv, fcntl, hashlib, json, math, os, shutil, subprocess, tempfile, zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--cosmonautics-jar',type=Path,required=True)
p.add_argument('--java-home',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--profiles',default='6')
p.add_argument('--cases',default='hover,tilt,flip90,flip150,flip180,climb,brake,rope12,rope32,rope-swing,rope-release,rope-offset')
p.add_argument('--mass',type=float,default=32)
p.add_argument('--inertia-scale',type=float,default=1)
p.add_argument('--delay',type=int,default=1)
p.add_argument('--noise',type=float,default=0)
p.add_argument('--com-x',type=float,default=0)
p.add_argument('--rotor-factor',type=float,default=1)
p.add_argument('--spool-factor',type=float,default=1)
p.add_argument('--attitude-noise',type=float,default=0)
p.add_argument('--seconds',type=int,default=60)
p.add_argument('--assert-all',action='store_true')
p.add_argument('--controller',type=Path,default=ROOT/'platforms/sputnik/dist/mintcraft-autopilot-quad-fpv.lua')
p.add_argument('--rope-length',type=float,default=5)
p.add_argument('--rope-mass',type=float)
a=p.parse_args();a.output=a.output.resolve();a.output.mkdir(parents=True,exist_ok=True)
lock_path=Path(tempfile.gettempdir())/('mintcraft-universal-'+hashlib.sha256(str(a.output).encode()).hexdigest()[:20]+'.lock')
lock=lock_path.open('a')
try: fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
except BlockingIOError: p.error('This output directory already has a running benchmark')
digest=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
m=json.loads((ROOT/'platforms/sputnik/dist/manifest.json').read_text())
assert digest(a.cosmonautics_jar)==m['hostJarSha256']
for name,record in m['artifacts'].items(): assert digest(ROOT/'platforms/sputnik/dist'/name)==record['sha256'],name
cases=a.cases.split(',');assert len(cases)==len(set(cases)) and set(cases)<=set('hover,cold-hover,diagonal,heave,tilt,flip90,flip150,flip180,climb,brake,rope12,rope32,rope-swing,rope-flight,rope-release,rope-offset'.split(','))
profiles=[int(x) for x in a.profiles.split(',')];assert all(x in (1,5,6) for x in profiles)
controller=a.controller.resolve()
controller_bytes=controller.read_bytes();controller_digest=hashlib.sha256(controller_bytes).hexdigest()
plant_bytes=(ROOT/'tools/sputnik-quad-fpv-twin.lua').read_bytes();plant_digest=hashlib.sha256(plant_bytes).hexdigest()
defaults_bytes=(ROOT/'platforms/sputnik/src/vehicle_model.lua').read_bytes();defaults_digest=hashlib.sha256(defaults_bytes).hexdigest()
fixture=dict(mass=a.mass,inertiaScale=a.inertia_scale,delay=a.delay,noise=a.noise,comX=a.com_x,rotorFactor=a.rotor_factor,ropeLength=a.rope_length,spoolFactor=a.spool_factor,attitudeNoise=a.attitude_noise,seconds=a.seconds)
if a.rope_mass is not None: fixture['ropeMass']=a.rope_mass
assert all(math.isfinite(v) for v in fixture.values())
assert a.seconds>=40 and 0<a.spool_factor<=2 and a.attitude_noise>=0
assert a.rope_length>0 and (a.rope_mass is None or a.rope_mass>0)
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
 bootstrap=folder/'bootstrap.lua';bootstrap.write_text('MINTCRAFT_UNIVERSAL_DEFAULTS='+json.dumps(str(defaults))+'\n'+'MINTCRAFT_UNIVERSAL_CONTROLLER='+json.dumps(str(snapshot))+'\n'+'MINTCRAFT_UNIVERSAL_OUTPUT='+json.dumps(str(work))+'\nMINTCRAFT_UNIVERSAL_PROFILES={'+','.join(map(str,profiles))+'}\nMINTCRAFT_FPV_CASES={'+','.join(json.dumps(x) for x in a.cases.split(','))+'}\nMINTCRAFT_UNIVERSAL_FIXTURE={'+','.join(k+'='+str(v) for k,v in fixture.items())+'}\n')
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
metadata=dict(pressure_oracle_sha256=digest(ROOT/'platforms/sputnik/tests/fixtures/sable-pressure.csv'),version=m['version'],controller_sha256=controller_digest,plant_sha256=plant_digest,defaults_sha256=defaults_digest,host_sha256=digest(a.cosmonautics_jar),csv_sha256=hashlib.sha256(raw).hexdigest(),fixture=fixture,passed=passed,total=len(rows),scenarios=rows,
 scope='Synthetic independent 6DOF plus unilateral point-mass cable in actual LuaJ. No Minecraft world qualification.',
 assumptions=['20 Hz controller; explicit Link delay and rotor spool multiplier; 200 Hz rigid-body integration', 'Sable pressure Java oracle; Aeronautics rotor formula; estimated shaft response', 'Mass exposed to controller excludes cable payload; no rope parameters sent to controller', 'Diagonal inertia 250/400/230 scaled by fixture; arms X=3 Z=5; gravity 11', 'No terrain, contacts, collisions, gyroscopic propeller torque, stress, real joint solver or ground effect', 'Unsupported small or heterogeneous fast profiles must be REFUSED; standard graph remains available'],
 criteria=['last 10s peak-to-peak altitude <1m; final altitude error <1m, final horizontal speed <.3m/s, tail tilt <5deg, tail speed RMS <.35m/s', 'Recovery settled within 8s; altitude loss reported, never treated as zero', 'Space 90% of 4m/s within 2s; brake pitch 90% within 1.5s', 'Cable extension <.03m; retained failures restrict supported domain'])
(a.output/'summary.json').write_text(json.dumps(metadata,indent=2,ensure_ascii=False)+'\n')
lines=['# Quad FPV '+m['version'],'',f'{passed}/{len(rows)} scenarios PASS. Synthetic LuaJ only; no Minecraft qualification.','', '| Scenario | Result | Height error m | Minimum altitude m | Tail tilt deg | Tail speed RMS m/s | Climb90 s | Brake s | Tail height span m | Tail vertical RMS m/s |','| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |']
for r in rows: lines.append('| '+r['scenario']+' | '+r['status']+' | '+' | '.join(r[k] for k in ('altitude_error','min_altitude','tail_tilt','tail_speed_rms','climb90_seconds','brake_seconds','tail_height_span','tail_vertical_rms'))+' |')
(a.output/'README.md').write_text('\n'.join(lines)+'\n')
print(f'Quad FPV LuaJ: {passed}/{len(rows)}; reports {a.output}')
if a.assert_all: assert passed==len(rows),'Inspect retained failures'
