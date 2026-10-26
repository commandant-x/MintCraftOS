from pathlib import Path
import sys,json,csv,hashlib,zipfile,collections,importlib.util,shutil,platform,subprocess
root=Path('/workspace/MintCraftOS');base=Path('/tmp/sputnik-ringing-033');out=root/'platforms/sputnik/reports/quad-ringing-0.3.2';out.mkdir(exist_ok=True)
spec=importlib.util.spec_from_file_location('diag',root/'tools/analyze-sputnik-quad-ringing.py');diag=importlib.util.module_from_spec(spec);spec.loader.exec_module(diag)
sys.path.insert(0,str(root/'tools'));from quad_campaign_contract import evaluate
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
shutil.copyfile(base/'analysis/transients.json',out/'native-campaign-transients.json')
(out/'.gitattributes').write_text('* -text\n*.csv whitespace=cr-at-eol\n')
archives={};stages=['','second','third','fourth','fifth','mpc-valid'];prototypes=[];frames=0;events=collections.Counter();models=set()
for n,stage in enumerate(stages,1):
 work=base/stage;records=json.loads((work/'search-results.json').read_text());archive=out/f'exploratory-traces-{n}.zip'
 with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  z.write(work/'search-results.json','original-search-results.json')
  script=base/('search.py' if n==1 else 'search2.py' if n==2 else 'search3.py' if n==3 else 'search4.py' if n==4 else 'search5.py' if n==5 else 'search-mpc-valid.py')
  z.write(script,'frozen-search.py')
  if n==6:z.write(base/'mpc-pwm.lua','frozen-mpc-pwm.lua')
  for v in records:
   folder=work/v['name'];assert sha(folder/'controller.lua')==v['sha256'];models.add(v['sha256'])
   item=dict(stage=n,name=v['name'],controller_sha256=v['sha256'],modified_utf8_bytes=v['modified_utf8_bytes'],historical_pass=v['passed'],cases=[])
   z.write(folder/'controller.lua',v['name']+'/controller.lua')
   for f in sorted(folder.glob('*/events.csv')):
    for ev in csv.DictReader(f.open()):
     assert ev['status'] in ('COMPLETE','FAULT','REFUSED'),ev
     path=f.parent/(ev['case']+'.csv');rows=[{k:float(value) for k,value in r.items()} for r in csv.DictReader(path.open())] if path.exists() else []
     score=evaluate(rows,ev,ev['case'],60);previous=next(r for r in v['results'] if r['fixture']==f.parent.name and r['movement']==ev['case'])
     for key in ('status','criteria','metrics','failures'):assert score[key]==previous[key]
     item['cases'].append(dict(fixture=f.parent.name,movement=ev['case'],**score,transient=diag.transient(rows,ev['case']),trace_sha256=sha(path) if path.exists() else None))
     events[ev['status']]+=1;frames+=int(float(ev['frames']))
    for path in sorted(f.parent.iterdir()):
     if path.name=='boot.lua' or path.suffix in ('.csv','.log'):z.write(path,v['name']+'/'+f.parent.name+'/'+path.name)
   prototypes.append(item)
 archives[archive.name]=dict(bytes=archive.stat().st_size,sha256=sha(archive))
 print('Archived exploratory stage',n,archive.stat().st_size,flush=True)
# Native intervention study: retain exact baseline controller and initial-attitude/source changes.
work=base/'native-correct';manifest=json.loads((work/'manifest.json').read_text());native=json.loads((work/'results.json').read_text());new=[]
for r in native:
 folder=work/r['fixture'];path=folder/(r['movement']+'.csv');assert sha(path)==r['trace_sha256']
 ev=next(ev for ev in csv.DictReader((folder/'events.csv').open()) if ev['case']==r['movement']);rows=[{k:float(value) for k,value in row.items()} for row in csv.DictReader(path.open())]
 score=evaluate(rows,ev,r['movement'],60)
 for key in ('status','criteria','metrics','failures'):assert score[key]==r[key]
 declared=float(r['fixture'].rsplit('tilt',1)[1]);assert abs(rows[0]['tilt']-declared)<1e-5,'Mutable initial quaternion or wrong declared tilt'
 new.append(dict(**r,transient=diag.transient(rows,r['movement'])))
(out/'native-interventions.json').write_text(json.dumps(dict(manifest=manifest,cases=new),indent=2)+'\n')
archive=out/'native-interventions.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 z.write(base/'native-correct-study.py','frozen-native-study.py')
 for path in sorted(work.rglob('*')):
  if path.is_file():z.write(path,path.relative_to(work))
 for name in ('tools/quad_campaign_contract.py','tools/sputnik-quad-campaign.lua','tools/analyze-sputnik-quad-ringing.py','tools/test-quad-ringing-diagnostics.py','platforms/sputnik/src/vehicle_model.lua','platforms/sputnik/tests/fixtures/sable-pressure.csv','platforms/sputnik/dist/mintcraft-autopilot-quad-fpv.lua'):z.write(root/name,'frozen-sources/'+name)
archives[archive.name]=dict(bytes=archive.stat().st_size,sha256=sha(archive))
(out/'explorations.json').write_text(json.dumps(dict(schema=1,interpreter='Lua 5.2 C, exploratory only; NOT native Sputnik validation',profiles=len(prototypes),distinct_controllers=len(models),events=dict(events),simulated_controller_frames=frames,simulated_hours=frames/20/3600,prototypes=prototypes),indent=2)+'\n')
assert all(v['bytes']<95000000 for v in archives.values())
(out/'artifacts.json').write_text(json.dumps(dict(schema=1,archives=archives,unchanged_controller_sha256=manifest['controller_sha256'],source_commit='a4d9d388de3629bc223885b3b6a97a2059b07a76',native_cases_verified=len(new),native_prior_traces_analyzed=552,exploratory_cases_verified=sum(len(v['cases']) for v in prototypes),scope='Research only; shipped controller and TXT unchanged'),indent=2)+'\n')
print('Native',len(new),collections.Counter(x['status'] for x in new),'exploratory',len(prototypes),frames,'archivebytes',sum(x['bytes'] for x in archives.values()),flush=True)
