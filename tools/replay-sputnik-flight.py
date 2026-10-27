#!/usr/bin/env python3
"""Validate and analyze MCLOG1 pages without executing imported text.

Optional native decision replay evaluates a controller on the recorded trajectory;
it does not predict the trajectory another controller would have flown.
"""
import argparse,csv,hashlib,io,json,math,subprocess,zipfile,os
from pathlib import Path
FIELDS='tick mass ix iy iz x y z pitch yaw roll vx vy vz target active forward left vertical residual saturated load dimension mode revision settings scale'.split()
STRINGS={'dimension','mode','settings'}
def fingerprint(text):
 n=0
 for c in text.encode('utf-8'):n=(n*33+c)%2147483647
 return n

def read_pages(paths):
 pages={};identity=None
 for path in paths:
  text=Path(path).read_text(encoding='utf-8').rstrip('\r\n');header,sep,body=text.partition('\n');row=header.split(';')
  if not sep or len(row)!=9 or row[0]!='MCLOG1':raise ValueError('MCLOG1 page header missing')
  values=[int(v) for v in row[1:]];epoch,sequence,page,total,count,dropped,checksum,mount=values
  if not (epoch>=0 and sequence>=0 and dropped>=0 and 1<=page<=total<=32 and 0<=count<=1200 and 0<=checksum<2147483647 and len(body.encode('utf-8'))<=44000):raise ValueError('Invalid page budget')
  key=(epoch,sequence,total,count,dropped,checksum,mount)
  if identity is not None and identity!=key:raise ValueError('Pages belong to different snapshots')
  if page in pages:raise ValueError('Duplicate page')
  identity=key;pages[page]=body
 if not identity or len(pages)!=identity[2]:raise ValueError('Missing pages')
 text='\n'.join(pages[i] for i in range(1,identity[2]+1))
 if fingerprint(text)!=identity[5]:raise ValueError('Snapshot checksum mismatch')
 frames=[];events=[];groups=[];settings=None;current=None
 for line in text.splitlines():
  tag,_,rest=line.partition(',')
  if tag=='S':
   if settings is not None or len(rest)>1024 or not rest.startswith('MCU1;'):raise ValueError('Invalid/duplicate settings')
   settings=rest
  elif tag=='C':
   if len(rest)>2400 or not rest.startswith('MCV1;') or len(groups)>=32:raise ValueError('Invalid group context')
   groups.append(rest)
  elif tag=='E':
   r=rest.split(',',2)
   if len(r)!=3 or len(events)>=64:raise ValueError('Invalid event')
   events.append(dict(tick=int(r[0]),kind=r[1],text=r[2]))
  elif tag=='MCF1':
   row=rest.split(',')
   if len(row)!=len(FIELDS):raise ValueError('Wrong sample width')
   current={}
   for name,value in zip(FIELDS,row):
    if name in STRINGS:current[name]=value
    elif value=='?':current[name]=None
    else:
     v=float(value)
     if not math.isfinite(v):raise ValueError('Nonfinite sample')
     current[name]=v
   for name in ('tick','mass','ix','iy','iz','x','y','z','pitch','yaw','roll','active','saturated'):
    if current[name] is None:raise ValueError('Missing required observation '+name)
   if current['tick']<=0 or current['tick']%1 or min(current[k] for k in ('mass','ix','iy','iz'))<=0:raise ValueError('Invalid physics context')
   if max(abs(current[k]) for k in ('x','y','z'))>30000000:raise ValueError('Impossible world coordinates')
   if current['scale'] is None or not .5<=current['scale']<=1:raise ValueError('Invalid runtime envelope')
   if current['active'] not in (0,1) or current['saturated'] not in (0,1):raise ValueError('Invalid flags')
   if any(current[k] is not None and not -1<=current[k]<=1 for k in ('forward','left','vertical')):raise ValueError('Invalid demand')
   if current['active']==1 and current['target'] is None:raise ValueError('Missing active target')
   if frames and current['tick']<=frames[-1]['tick']:raise ValueError('Stale/regressing recorded time')
   current['groups']=[];frames.append(current)
  elif tag=='G':
   row=rest.split(',')
   if current is None or len(row)!=4 or len(current['groups'])>=32:raise ValueError('Orphan/invalid motor record')
   ident,level,rpm,check=row;ident=int(ident);level=None if level=='?' else float(level);rpm=None if rpm=='?' else float(rpm);check=int(check)
   if ident<1 or ident>32 or any(g['id']==ident for g in current['groups']) or not 0<=check<2147483647:raise ValueError('Invalid motor identifier/checksum')
   if level is not None and (not math.isfinite(level) or level%1 or not 0<=level<=15):raise ValueError('Invalid emitted level')
   if rpm is not None and (not math.isfinite(rpm) or not 0<=rpm<=100000):raise ValueError('Invalid estimated RPM')
   current['groups'].append(dict(id=ident,level=level,state_estimated=rpm,hash=check))
  else:raise ValueError('Unknown record '+tag)
 if len(frames)!=identity[3]:raise ValueError('Frame count mismatch')
 if len(groups)!=len(set(g.split(';')[1] for g in groups)):raise ValueError('Duplicate context identifier')
 if settings is not None:
  if fingerprint(settings+'\n'+'\n'.join(groups))!=identity[6]:raise ValueError('Mount context checksum mismatch')
  hashes={int(g.split(';')[1]):fingerprint(g) for g in groups}
  for frame in frames:
   if frame['active']==1:
    if frame['settings']!=settings or len(frame['groups'])!=len(groups) or any(hashes.get(g['id'])!=g['hash'] for g in frame['groups']):raise ValueError('Recorded active mount does not match context')
 kinds={int(g.split(';')[1]):g.split(';')[2] for g in groups}
 for frame in frames:
  for g in frame['groups']:
   kind=kinds.get(g['id']);g['state_unit']='rpm' if kind in ('small','bearing') else 'command_level' if kind in ('linear','surface') else 'unknown'
 return dict(epoch=identity[0],sequence=identity[1],dropped=identity[4],settings=settings,groups=groups,frames=frames,events=events,checksum=identity[5])

def analyze(log):
 frames=log['frames'];active=[f for f in frames if f['active']==1];gaps=sum(b['tick']-a['tick']>1 for a,b in zip(frames,frames[1:]));missing=sum(max(0,int(b['tick']-a['tick']-1)) for a,b in zip(frames,frames[1:]))
 errors=[abs(f['y']-f['target']) for f in active if f['target'] is not None];result=dict(schema=1,source='recorded-writer-observations',hardware_ack=False,qualified=False,frames=len(frames),active_frames=len(active),gaps=gaps,missing_ticks=missing,dropped_before_snapshot=log['dropped'],mount_verified=log['settings'] is not None,max_height_error=max(errors,default=None),first_fault=next((e for e in log['events'] if e['kind']=='FAULT'),None),limits=['No direct shaft RPM or radio ACK inferred','Clock gaps do not grant stability','No obstacle/COM scan','Re-evaluation is not a counterfactual physical trajectory'])
 if active:
  result['max_abs_pitch']=max(abs(f['pitch']) for f in active);result['max_abs_roll']=max(abs(f['roll']) for f in active);result['saturated_fraction']=sum(f['saturated'] for f in active)/len(active)
 # Report every contiguous measured stationary interval; do not qualify by duration alone.
 intervals=[];start=None;count=0;previous=None
 for f in frames:
  ok=f['active']==1 and all(f[k] is not None for k in ('target','vx','vy','vz','forward','left','vertical')) and abs(f['y']-f['target'])<=1 and abs(f['vy'])<=.1 and math.hypot(f['vx'],f['vz'])<=.2 and abs(f['pitch'])<=5 and abs(f['roll'])<=5 and f['forward']==f['left']==f['vertical']==0
  if previous and (f['tick']!=previous['tick']+1 or f['target']!=previous['target']):
   if count>=20:intervals.append(dict(start_tick=start,end_tick=previous['tick'],fresh_observations=count))
   start=None;count=0
  if ok:
   if start is None:start=f['tick']
   count+=1
  else:
   if count>=20:intervals.append(dict(start_tick=start,end_tick=previous['tick'],fresh_observations=count))
   start=None;count=0
  previous=f
 if count>=20:intervals.append(dict(start_tick=start,end_tick=previous['tick'],fresh_observations=count))
 result['stationary_intervals']=intervals;return result

def lua(value):
 if value is None:return 'nil'
 if isinstance(value,bool):return 'true' if value else 'false'
 if isinstance(value,(float,int)):return repr(value)
 if isinstance(value,str):return json.dumps(value,ensure_ascii=True)
 if isinstance(value,list):return '{'+','.join(lua(v) for v in value)+'}'
 return '{'+','.join('['+lua(k)+']='+lua(v) for k,v in value.items())+'}'

def replay(log,controller,jar,jdk,out):
 if not log['settings'] or not log['groups']:raise ValueError('Verified mount context is required for decision replay')
 if any(f['dimension']!='minecraft:overworld' for f in log['frames'] if f['active']==1):raise ValueError('Unsupported active dimension')
 out.mkdir(parents=True,exist_ok=True)
 root=Path(__file__).resolve().parent.parent
 expected=json.loads((root/'platforms/sputnik/dist/manifest.json').read_text())['hostJarSha256']
 if hashlib.sha256(jar.read_bytes()).hexdigest()!=expected:raise ValueError('Unaudited LuaJ JAR')
 runtime=out/'runtime.jar'
 with zipfile.ZipFile(jar) as src,zipfile.ZipFile(runtime,'w') as target:
  for name in src.namelist():
   if name.startswith('dev/devce/rocketnautics/shaded/luaj/') and name.endswith('.class'):target.writestr(name,src.read(name))
 subprocess.run([str(jdk/'bin/javac'),'-cp',str(runtime),'-d',str(out),str(root/'tools/VerifySputnikLua.java')],check=True)
 config=dict(log=log,controller=str(controller.resolve()),output=str((out/'decisions.csv').resolve()))
 boot=out/'replay-bootstrap.lua';boot.write_text('MINTCRAFT_REPLAY='+lua(config)+'\n')
 with (out/'runtime.log').open('w') as target:subprocess.run([str(jdk/'bin/java'),'-XX:ActiveProcessorCount=1','-XX:+UseSerialGC','-Xmx512m','-cp',str(out)+os.pathsep+str(runtime),'VerifySputnikLua',str(boot),str(root/'tools/sputnik-observation-replay.lua')],stdout=target,stderr=subprocess.STDOUT,check=True,timeout=180)
 (out/'replay-metadata.json').write_text(json.dumps(dict(controller_sha256=hashlib.sha256(controller.read_bytes()).hexdigest(),host_sha256=expected,scope='Fresh controller re-evaluation on recorded poses. Warm start and missing internal state prevent bit-exact or physical counterfactual claims.',original_samples=len(log['frames']),source_checksum=log['checksum']),indent=2)+'\n')

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('pages',nargs='+',type=Path);p.add_argument('--output',type=Path,required=True);p.add_argument('--controller',type=Path);p.add_argument('--cosmonautics-jar',type=Path);p.add_argument('--java-home',type=Path);a=p.parse_args()
 log=read_pages(a.pages);a.output.mkdir(parents=True,exist_ok=True)
 (a.output/'analysis.json').write_text(json.dumps(analyze(log),indent=2,ensure_ascii=False)+'\n')
 (a.output/'observations.json').write_text(json.dumps(log,indent=2,ensure_ascii=False)+'\n')
 with (a.output/'observations.csv').open('w',newline='') as file:
  writer=csv.DictWriter(file,fieldnames=FIELDS);writer.writeheader();writer.writerows({k:f.get(k) for k in FIELDS} for f in log['frames'])
 with (a.output/'actuators.csv').open('w',newline='') as file:
  writer=csv.writer(file);writer.writerow(['tick','id','requested_level','estimated_state','estimated_unit','descriptor_checksum'])
  for frame in log['frames']:
   for group in frame['groups']:writer.writerow([frame['tick'],group['id'],group['level'],group['state_estimated'],group['state_unit'],group['hash']])
 if a.controller:
  if not a.cosmonautics_jar or not a.java_home:p.error('--controller requires --cosmonautics-jar and --java-home')
  replay(log,a.controller,a.cosmonautics_jar,a.java_home,a.output.resolve()/'native-replay')
 print('Validated',len(log['frames']),'recorded samples; analysis only, no hardware or physical qualification')
if __name__=='__main__':main()
