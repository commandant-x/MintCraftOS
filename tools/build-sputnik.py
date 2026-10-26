#!/usr/bin/env python3
"""Build stock Sputnik Lua and its actual Base64/SNBT clipboard format; no downloads."""
from pathlib import Path
import base64, fcntl, hashlib, json, re, struct, tempfile, uuid, zipfile
from lua_compact import compact
ROOT=Path(__file__).resolve().parent.parent
BASE=ROOT/'platforms/sputnik'
VERSION='0.3.3'
MODULES=['system.ascendancy.contracts']+['system.navigation.'+name for name in (
 'geometry','state_estimator','authority','response_model','measured_controller','closed_loop_qualification',
 'output_characterization','tilt_response','known_flight','motion_progress',
 'altitude_model','altitude_sweep','sweep_progress','autopilot')]+['platforms.sputnik.src.drive_mixer']
def source(path): return path.read_text(encoding='utf-8').replace('\r\n','\n')
def bundle():
 chunks=['local function makePortableModules()\n local factories,cache={},{}\n']
 paths={'system.libraries.addon':BASE/'src/portable.lua'}
 paths.update({name:ROOT/(name.replace('.','/')+'.lua') for name in MODULES})
 manifest={}
 for name,path in paths.items():
  text=source(path); manifest[name]=hashlib.sha256(text.encode()).hexdigest()
  chunks.append(' factories['+json.dumps(name)+']=function(require)\n')
  if name=='system.ascendancy.contracts':
   chunks.append(" local os={clock=function() local t=type(getUniverseTime)=='function' and getUniverseTime() or nil assert(type(t)=='number' and t==t and t>=0 and t<math.huge,'Sputnik server clock unavailable') return t/20 end}\n")
  chunks.append(text+'\n end\n')
 chunks.append(" local function require(name)\n  assert(type(name)=='string' and factories[name],'Module not included in Sputnik edition')\n  if cache[name]~=nil then return cache[name] end\n  local value=factories[name](require) cache[name]=value return value\n end\n return require\nend\n")
 return ''.join(chunks),manifest
def quote(text):
 # SNBT uses Brigadier quoted strings: only quote/backslash escapes, no JSON \n escapes.
 return '"'+text.replace('\\','\\\\').replace('"','\\"')+'"'
def nbt_utf8_size(text):
 # DataOutput.writeUTF encodes UTF-16 units with modified UTF-8, not UTF-8.
 raw=text.encode('utf-16-be','surrogatepass')
 return sum(1 if 1<=v<=127 else 2 if v<=2047 else 3 for v in struct.unpack('>'+str(len(raw)//2)+'H',raw))
def pins(code):
 found={'input':[], 'output':[]}
 pattern=re.compile(r"(input|output)\(\s*[\"']([^\"']+)[\"']\s*(?:,\s*[\"']([^\"']+)[\"'])?")
 for line in code.splitlines():
  for match in pattern.finditer(line.split('--',1)[0]):
   kind,name,raw=match.groups()
   assert name not in [v[0] for v in found[kind]],'Duplicate native pin '+name
   typ='STRING' if raw and raw.lower() in ('string','str','text') else 'ANY' if raw=='any' else 'NUMBER'
   found[kind].append((name,typ))
 return found
def pin_tags(values,kind):
 return '['+','.join('{name:'+quote(name)+',valueType:'+quote(typ)+',pinType:'+quote(kind)+',color:-1,value:0.0d,stringValue:""}' for name,typ in values)+']'
def uuid_tag(ident): return '[I;'+','.join(str(v) for v in struct.unpack('>4i',ident.bytes))+']'
def graph_clipboard(nodes,edges,types=None):
 types=types or {}
 identifiers={name:uuid.uuid5(uuid.NAMESPACE_URL,'https://github.com/commandant-x/MintCraftOS/sputnik/'+name) for name,code,x,y in nodes}
 metadata={name:pins(code) for name,code,x,y in nodes}
 records=[]
 for name,code,x,y in nodes:
  assert nbt_utf8_size(code)<=60000,'Unsafe native node size'
  records.append('{id:'+uuid_tag(identifiers[name])+',typeId:'+quote(types.get(name,'rocketnautics:lua_script'))+',title:'+quote('MintCraft '+name)+',x:'+str(x)+',y:'+str(y)+',inputs:'+pin_tags(metadata[name]['input'],'INPUT')+',outputs:'+pin_tags(metadata[name]['output'],'OUTPUT')+',elements:[],customData:{code:'+quote(code)+'}}')
 connections=[]
 for src,out,tgt,inp in edges:
  source_index=[v[0] for v in metadata[src]['output']].index(out)
  target_index=[v[0] for v in metadata[tgt]['input']].index(inp)
  connections.append('{src:'+uuid_tag(identifiers[src])+',srcP:'+str(source_index)+',tgt:'+uuid_tag(identifiers[tgt])+',tgtP:'+str(target_index)+'}')
 text='{nodes:['+','.join(records)+'],conns:['+','.join(connections)+']}'
 return base64.b64encode(text.encode()).decode()
def clipboard(name,code): return graph_clipboard([(name,code,40,40)],[])
def native_universal():
 def wrapped(name,text): return 'local '+name+'=(function()\n'+text+'\nend)()\n'
 response=source(ROOT/'system/navigation/response_model.lua')
 # Verbatim existing allocator/quantizer and validators, without CC provenance IO.
 response=response[response.index('local M={}'):response.index('-- Coupled error diffusion')]
 response=response.replace('local floors={.01,.01,.01,.1,.1,.1}\n','')
 geometry=source(ROOT/'system/navigation/geometry.lua').replace('local addon = require("system.libraries.addon")','local addon = Portable')
 geometry=geometry[:geometry.index('function M.heading(')]+'return M\n'
 geometry=geometry.replace('function M.wrap(angle) return (angle + 180) % 360 - 180 end\n','')
 progress=source(ROOT/'system/navigation/motion_progress.lua').replace("local A=require('system.libraries.addon')",'local A=Portable')
 for original,short in [('Collecting physical progress evidence','Collecte progres'),('Physical errors are not converging; no qualification granted by waiting','Pas de convergence'),('Observed errors converge or remain within the diagnostic band','Progres observe')]: progress=progress.replace(original,short)
 filters=source(BASE/'src/quad_control.lua');filters=filters[filters.index('local M={}'):filters.index('local function inverse')]
 physics=source(BASE/'src/aero_physics.lua');physics=physics[:physics.index('-- Effective per-RPM coefficients')]+'return M\n'
 prefix=wrapped('Portable',source(BASE/'src/portable.lua'))+wrapped('Geometry',geometry)+wrapped('Physics',physics)
 prefix+=wrapped('Response','local A=Portable\n'+response+'\nreturn M')+wrapped('Progress',progress)+wrapped('Filter',filters+'\nreturn M')
 vehicle=source(BASE/'src/vehicle_model.lua');vehicle=vehicle[:vehicle.index('function M.defaults(')]+vehicle[vehicle.index('function M.validate('):]
 prefix+=wrapped('Vehicle',vehicle)+wrapped('Mission',source(BASE/'src/flight_mission.lua'))+wrapped('Calibration',source(BASE/'src/flight_calibration.lua'))+wrapped('Flight',source(BASE/'src/flight_core.lua'))
 names=['Portable','Geometry','Physics','Response','Progress','Filter','Vehicle','Mission','Calibration','Flight']
 prefix='if not _G.MintCraftFlightModules then\n'+prefix+'\n_G.MintCraftFlightModules={'+','.join(names)+'}\nend\nlocal __modules=_G.MintCraftFlightModules\nlocal '+','.join(names)+'='+','.join('__modules['+str(i)+']' for i in range(1,len(names)+1))+'\n'
 model=source(BASE/'src/vehicle_model.lua')
 fields=model[model.index('M.fields=')+len('M.fields='):model.index('\nlocal numeric=')]
 defaults=model[model.index('function M.defaults('):model.index('function M.validate(')]
 mount_prefix='local GROUP_DEFAULT=1\nlocal MountFields='+fields+'\n'+wrapped('MountDefaults','local M={}\n'+defaults+'\nreturn M.defaults')
 mount=mount_prefix+source(BASE/'src/mount-node.lua')
 simple=mount_prefix+'local PROFILE_DEFAULT=1\n'+source(BASE/'src/mount-simple.lua')
 slim_bus=source(BASE/'src/groups-simple.lua').replace('GROUP_COUNT','4').replace('GROUP_INPUTS',','.join("input('Group "+str(i)+"','string')" for i in range(1,5))).replace('OBSERVATION_INPUTS',','.join("input('Observation "+str(i)+"','string')" for i in range(1,5)))
 return {'autopilot-control':prefix+source(BASE/'src/autopilot-node.lua'),'mount-group':mount,'mount-simple':simple,'groups-simple':slim_bus,'mount-bus':source(BASE/'src/mount-bus.lua'),'mount-setup':source(BASE/'src/setup-node.lua'),'flight-commands':source(BASE/'src/command-node.lua'),'local-map':source(BASE/'src/map-node.lua')}
def native_quad_fpv():
 # Dedicated writer: never inject experimental attitude control into other profiles.
 text=native_universal()['autopilot-control']
 start=text.index('function M.solve(model,wanted)');end=text.index('function M.signals(',start)
 text=text[:start]+source(BASE/'src/quad-allocator.lua')+'\n'+text[end:]
 start=text.index('local Response=(function()');end=text.index('\nend)()',start)+len('\nend)()')
 text=text[:start]+"local Response={axes={'forward','right','vertical','pitch','yaw','roll'}}"+text[end:]
 start=text.index('function M.signals(meta,values,quant)');end=text.index('function M.capabilities(',start)
 text=text[:start]+source(BASE/'src/quad-pwm.lua')+'\n'+text[end:]
 start=text.index('function M.capabilities(');end=text.index('return M\n',start)
 text=text[:start]+source(BASE/'src/quad-capabilities.lua')+'\n'+text[end:]
 start=text.index(' function s:step(p,command,lastSignals,feedback)');end=text.rfind('end)()',start,text.index('_G.MintCraftFlightModules={'))
 return (text[:start]+source(BASE/'src/quad-flight-step.lua')+text[end:]).replace('c.tilt>20','c.tilt>45').replace('Descriptor schema/field count','incomplet: voir formulaire moteur').replace('for _,text in ipairs(descriptors) do','for groupIndex,text in ipairs(descriptors) do').replace('Vehicle.decode(text);if not g then return nil,why end',"Vehicle.decode(text);if not g then return nil,'Moteur '..groupIndex..': '..why end")

def fpv_graph(scripts,consent):
 scripts=dict(scripts);scripts['autopilot-control']=scripts['autopilot-quad-fpv']
 scripts['mount-setup']=scripts['mount-setup'].replace("'Consigne montee m/s','1'","'Consigne montee m/s','4'").replace("'Inclinaison deplacement: 0 < deg <= 20','8'","'Inclinaison deplacement: 0 < deg <= 45','20'").replace("'tilt',0,20,","'tilt',0,45,").replace('valeur <= 20 deg','valeur <= 45 deg').replace("'Deceleration de planification estimee m/s2','1'","'Deceleration de planification estimee m/s2','4'")
 scripts['mount-simple']=scripts['mount-simple'].replace('local base=MountDefaults(PROFILE_DEFAULT,GROUP_DEFAULT)','local base=MountDefaults(PROFILE_DEFAULT,GROUP_DEFAULT);base.kind=\'bearing\';base.sails=12')
 return architecture_graph(scripts,consent,1,4,'quad-fpv','Quad: 4 helices verticales')

def architecture_graph(scripts,consent,profile,count,slug,label):
 # Keep the exact flight writer; reduce only editor forms, pins and rendering.
 setup=scripts['mount-setup'].replace("profile=ui.slider('Architecture',1,5,300)","profile=ui.label('Architecture fixe: "+label+"')")
 setup=setup.replace('s.profile.setValue(1);','').replace('math.floor(s.profile.getValue()+.5)',str(profile))
 setup=setup.replace('Montage commun: 1 Quad / 2 Ballon / 3 Venator / 4 Helicoptere / 5 Hybride','Montage '+label)
 bus=source(BASE/'src/groups-simple.lua').replace('GROUP_COUNT',str(count)).replace('GROUP_INPUTS',','.join("input('Group "+str(i)+"','string')" for i in range(1,count+1))).replace('OBSERVATION_INPUTS',','.join("input('Observation "+str(i)+"','string')" for i in range(1,count+1)))
 nodes=[('enable',consent,20,40),('keyboard',scripts['typewriter'],20,400),('montage',setup,350,40),('commands',scripts['flight-commands'],750,40),('autopilot',scripts['autopilot-control'],1300,40),('groups',bus,1300,700)]
 edges=[('enable','Enable','autopilot','Enable'),('enable','Binding','autopilot','Enable binding'),('enable','Enable','keyboard','Enable'),('keyboard','Bindings','autopilot','Keyboard bindings'),('montage','Settings','autopilot','Settings'),('commands','Request','autopilot','Request'),('autopilot','Acknowledged revision','commands','Acknowledged revision'),('autopilot','Status','commands','Status'),('autopilot','Position','commands','Position')]
 for pin in ('Groups A','Groups B','Observations A','Observations B'): edges.append(('groups',pin,'autopilot',pin))
 for pin in ('Commands valid','Forward demand','Left demand','Vertical demand'): edges.append(('keyboard',pin,'autopilot',pin))
 for i in range(1,count+1):
  name='group-'+str(i)
  code=scripts['mount-simple'].replace('local GROUP_DEFAULT=1\n','local GROUP_DEFAULT='+str(i)+'\n',1)
  code=code.replace('local PROFILE_DEFAULT=1\n','local PROFILE_DEFAULT='+str(profile)+'\n')
  nodes.append((name,code,20+(i-1)*450,1250))
  edges.extend([('montage','Architecture',name,'Architecture'),(name,'Group','groups','Group '+str(i)),(name,'Shaft observation','groups','Observation '+str(i))])
 # Different variants must not reuse node UUIDs when pasted into another graph.
 rename=lambda name:slug+'-'+name
 return [(rename(n),c,x,y) for n,c,x,y in nodes],[(rename(a),b,rename(c),d) for a,b,c,d in edges]

def main():
 out=BASE/'dist';out.mkdir(exist_ok=True)
 prefix,modules=bundle()
 probe='local Probe=(function()\n'+source(BASE/'src/bank_probe.lua')+'\nend)()\n'
 bank=probe+'local BANK_DEFAULT=1\n'+source(BASE/'src/bank-test-node.lua')
 sequencer=source(BASE/'src/test-sequencer.lua')
 consent=source(BASE/'src/test-enable.lua')
 mixer="local Mixer=(function()\n"+source(BASE/'src/drive_mixer.lua')+"\nend)()\n"+source(BASE/'src/drive-console.lua')
 vehicle="local Mixer=(function()\n"+source(BASE/'src/drive_mixer.lua')+"\nend)()\n"+source(BASE/'src/vehicle-console.lua')
 quad="local Physics=(function()\n"+source(BASE/'src/aero_physics.lua')+"\nend)()\nlocal Quad=(function()\n"+source(BASE/'src/quad_control.lua')+"\nend)()\nQuad.Physics=Physics\n"+source(BASE/'src/quad-node.lua')
 scripts={'architecture-selector':source(BASE/'src/architecture-selector.lua'),'flight-telemetry':source(BASE/'src/flight-telemetry.lua'),'link-test':source(BASE/'src/link-test.lua'),'quad-control':quad,'typewriter':source(BASE/'src/typewriter.lua'),'vehicle-mixer':vehicle,'bank-test':bank,'test-sequencer':sequencer,'test-enable':consent,'drive-mixer':mixer,'import-test':source(BASE/'src/import-test.lua'),'dashboard':source(BASE/'src/dashboard.lua'),'link-gateway':source(BASE/'src/gateway.lua'),'numeric-radio':source(BASE/'src/radio.lua')}
 scripts.update(native_universal())
 scripts['autopilot-quad-fpv']=native_quad_fpv()
 # Token whitespace compaction preserves literals/operators and source lines.
 # Readable module sources remain the source of truth.
 aliases={name:'_'+str(i) for i,name in enumerate(['Portable','Geometry','Physics','Response','Progress','Filter','Vehicle','Mission','Calibration','Flight'])}
 aliases.update({name:'_'+chr(65+i) for i,name in enumerate(['worldAx','worldAz','desiredYaw','worldRate','requestedSpeed','provisional'])})
 scripts['autopilot-control']=compact(scripts['autopilot-control'],aliases,keep_lines=False,private_identifiers=True,explicit_methods=True)
 scripts['autopilot-quad-fpv']=compact(scripts['autopilot-quad-fpv'],aliases,keep_lines=False,private_identifiers=True,explicit_methods=True)
 artifacts={}
 (out/'sdk').mkdir(exist_ok=True)
 (out/'profiles').mkdir(exist_ok=True)
 for profile in sorted((BASE/'profiles').glob('*.json')):
  content=profile.read_bytes();dest=out/'profiles'/profile.name;dest.write_bytes(content)
  artifacts['profiles/'+profile.name]={'bytes':len(content),'sha256':hashlib.sha256(content).hexdigest()}
 library=prefix+'return makePortableModules()\n';(out/'sdk/mintcraft-library.lua').write_text(library)
 artifacts['sdk/mintcraft-library.lua']={'bytes':len(library.encode()),'sha256':hashlib.sha256(library.encode()).hexdigest()}
 for name,code in scripts.items():
  assert nbt_utf8_size(code)<=60000,'Node exceeds safe modified-UTF NBT string budget'
  for suffix,text in [('.lua',code),('.clipboard.txt',clipboard(name,code))]:
   path=out/('mintcraft-'+name+suffix);path.write_text(text,encoding='utf-8')
   artifacts[path.name]={'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
 # Read-only addon preserves an existing vehicle graph and its settings.
 audit_nodes=[('flight-telemetry',scripts['flight-telemetry'],40,40),('flight-screen',"input('Text','string')",900,40)]
 audit_edges=[('flight-telemetry','Telemetry','flight-screen','Text')]
 path=out/'mintcraft-flight-audit.clipboard.txt'
 path.write_text(graph_clipboard(audit_nodes,audit_edges,{'flight-screen':'websnodelib:string_display'}),encoding='utf-8')
 artifacts[path.name]={'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
 # A complete two-bank graph: all logical ports connected, physical frequencies blank.
 graph_nodes=[('test-enable',consent,20,40),('test-sequencer',sequencer,360,40),('bank-1',bank,900,40),('bank-2',bank.replace('local BANK_DEFAULT=1','local BANK_DEFAULT=2'),1500,40)]
 graph_edges=[('test-enable','Enable','test-sequencer','Enable'),('test-enable','Binding','test-sequencer','Enable binding')]
 for i in (1,2):
  target='bank-'+str(i)
  graph_edges.extend([('test-enable','Enable',target,'Enable'),('test-enable','Binding',target,'Enable binding'),('test-sequencer','Selected group',target,'Selected group'),('test-sequencer','Session',target,'Session')])
  for output_pin,inp in [('Group index','Group'),('Ready','Ready'),('Bindings','Bindings'),('Done session','Done'),('Failed session','Failed')]:
   graph_edges.append((target,output_pin,'test-sequencer',inp+' '+str(i)))
 path=out/'mintcraft-two-bank-tests.clipboard.txt'
 path.write_text(graph_clipboard(graph_nodes,graph_edges),encoding='utf-8')
 artifacts[path.name]={'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
 # Separate keyboard/quad graph; consent and outputs remain unconfigured.
 quad_nodes=[('architecture',scripts['architecture-selector'],20,-240),('quad-enable',consent,20,40),('quad-keyboard',scripts['typewriter'],350,40),('quad-controller',quad,1100,40),('quad-status',"input('Text','string')",2050,40)]
 quad_edges=[('architecture','Architecture','quad-controller','Architecture'),('quad-enable','Binding','quad-controller','Enable binding'),('quad-keyboard','Bindings','quad-controller','Keyboard bindings'),('quad-enable','Enable','quad-keyboard','Enable'),('quad-enable','Enable','quad-controller','Flight Enable')]
 for pin in ('Forward demand','Left demand','Vertical demand','Commands valid'):
  quad_edges.append(('quad-keyboard',pin,'quad-controller',pin))
 quad_edges.append(('quad-controller','Status','quad-status','Text'))
 quad_nodes.extend([(name,code,x+2800,y) for name,code,x,y in audit_nodes])
 quad_edges.extend(audit_edges)
 for src,out_pin,inp in [('quad-controller','Active','Controller active'),('quad-controller','Target altitude','Target altitude'),('quad-keyboard','Commands valid','Keyboard valid'),('quad-keyboard','Forward demand','Forward demand'),('quad-keyboard','Left demand','Left demand'),('quad-keyboard','Vertical demand','Vertical demand')]:
  quad_edges.append((src,out_pin,'flight-telemetry',inp))
 path=out/'mintcraft-quad-flight.clipboard.txt'
 path.write_text(graph_clipboard(quad_nodes,quad_edges,{'quad-status':'websnodelib:string_display','flight-screen':'websnodelib:string_display'}),encoding='utf-8')
 artifacts[path.name]={'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
 # Universal graph: exactly one physical writer, independent montage/consignes/map.
 universal_nodes=[('mount-bus',scripts['mount-bus'],1100,700),('pilot-enable',consent,20,40),('montage',scripts['mount-setup'],350,40),('pilot-keyboard',scripts['typewriter'],20,500),('pilot-commands',scripts['flight-commands'],700,40),('autopilot',scripts['autopilot-control'],1600,40),('pilot-status',"input('Text','string')",2250,40),('local-map',scripts['local-map'],2250,300)]
 universal_edges=[('mount-bus','Groups A','autopilot','Groups A'),('mount-bus','Groups B','autopilot','Groups B'),('mount-bus','Observations A','autopilot','Observations A'),('mount-bus','Observations B','autopilot','Observations B'),('pilot-enable','Enable','autopilot','Enable'),('pilot-enable','Binding','autopilot','Enable binding'),('pilot-enable','Enable','pilot-keyboard','Enable'),('montage','Settings','autopilot','Settings'),('pilot-commands','Request','autopilot','Request'),('autopilot','Acknowledged revision','pilot-commands','Acknowledged revision'),('autopilot','Status','pilot-commands','Status'),('autopilot','Position','pilot-commands','Position'),('autopilot','Status','pilot-status','Text'),('pilot-keyboard','Bindings','autopilot','Keyboard bindings')]
 for pin in ('Commands valid','Forward demand','Left demand','Vertical demand'): universal_edges.append(('pilot-keyboard',pin,'autopilot',pin))
 for pin in ('Geometry','Route','Position','Trace'): universal_edges.append(('autopilot',pin,'local-map',pin))
 for i in range(1,9):
  name='groupe-'+str(i);code=scripts['mount-group'].replace('local GROUP_DEFAULT=1\n','local GROUP_DEFAULT='+str(i)+'\n',1)
  universal_nodes.append((name,code,350+(i-1)%4*500,1100+(i-1)//4*1600))
  universal_edges.extend([('montage','Architecture',name,'Architecture'),(name,'Group','mount-bus','Group '+str(i)),(name,'Shaft observation','mount-bus','Observation '+str(i))])
 path=out/'mintcraft-autopilot.clipboard.txt'
 path.write_text(graph_clipboard(universal_nodes,universal_edges,{'pilot-status':'websnodelib:string_display'}),encoding='utf-8')
 artifacts[path.name]={'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
 architecture_graphs={}
 for profile,count,slug,label in ((1,4,'quad','Quad'),(2,4,'balloon','Ballon'),(3,6,'venator','Venator'),(4,4,'helicopter','Helicoptere')):
  nodes,edges=architecture_graph(scripts,consent,profile,count,slug,label)
  path=out/('mintcraft-'+slug+'-autopilot.clipboard.txt')
  path.write_text(graph_clipboard(nodes,edges),encoding='utf-8')
  artifacts[path.name]={'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
  architecture_graphs[slug]={'file':path.name,'profile':profile,'groups':count,'nodes':len(nodes),'connections':len(edges),'mapIncluded':False,'flightControllerSha256':hashlib.sha256(scripts['autopilot-control'].encode()).hexdigest()}
 nodes,edges=fpv_graph(scripts,consent)
 path=out/'mintcraft-quad-fpv.clipboard.txt';path.write_text(graph_clipboard(nodes,edges),encoding='utf-8')
 artifacts[path.name]={'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
 manifest={'schema':1,'edition':'MintCraft Sputnik','version':VERSION,'target':'Cosmonautics 26.08.307 / Minecraft 1.21.1',
  'hostJarSha256':'3fd9dac868400905a55164d2c9d74abc2080ae3269ca51e54e1899874945973e',
  'import':'Base64 UTF-8 SNBT, WNodeScreen clipboard nodes/conns','testedInMinecraft':False,
  'qualifiedAutopilot':False,'defaultActuation':False,'nativeNodeModifiedUtf8Budget':60000,
  'contracts':{'mount':'MCV1','settings':'MCU1 (10 legacy / 11 current fields)','request':'MCC1','candidateModel':'MCAL1','missionSchema':1,'observations':{'schema':1,'encoding':'id,rpm,universeTick','meaning':'optional observed shaft speed; no gearshift ACK'}},
  'nativeSources':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((BASE/'src').glob('*.lua'))},
  'experimentalQuadFpv':{'file':'mintcraft-quad-fpv.clipboard.txt','nodes':10,'connections':29,'scope':'four declared vertical rotors, per-rotor model and collective priority; synthetic validation only','controllerSha256':hashlib.sha256(scripts['autopilot-quad-fpv'].encode()).hexdigest()},
  'architectureGraphs':architecture_graphs,'developerLibraryImportableAsSingleNode':False,'nodeModifiedUtf8Bytes':{name:nbt_utf8_size(code) for name,code in scripts.items()},'modules':modules,'artifacts':artifacts}
 (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 files=sorted(p for p in out.rglob('*') if p.is_file() and p.suffix!='.zip' and p.name!='SHA256SUMS')
 archive=out/('mintcraft-sputnik-'+VERSION+'.zip')
 with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  for path in files:
   entry=zipfile.ZipInfo(path.relative_to(out).as_posix(),(2026,10,24,0,0,0));entry.compress_type=zipfile.ZIP_DEFLATED;entry.external_attr=0o644<<16
   z.writestr(entry,path.read_bytes())
  for name in ('README.md','AUTOPILOT.md','IMPLEMENTATION-STATUS.md','COMPATIBILITY.md','VEHICLE-PROFILES.md','WIRING-AND-TESTS.md','QUAD-FLIGHT.md','QUAD-FPV.md','LICENSE'):
   path=ROOT/name if name=='LICENSE' else BASE/name
   if path.exists():
    entry=zipfile.ZipInfo(name,(2026,10,24,0,0,0));entry.compress_type=zipfile.ZIP_DEFLATED;entry.external_attr=0o644<<16;z.writestr(entry,path.read_bytes())
 # Readable sources, test programs and completed reports accompany this edition.
  source_paths=set((BASE/'src').glob('*.lua')) | set((BASE/'tests').rglob('*')) | set((BASE/'profiles').glob('*.json'))
  source_paths.update(BASE.glob('*.md'));source_paths.add(ROOT/'LICENSE')
  source_paths.update(ROOT/(name.replace('.','/')+'.lua') for name in MODULES)
  source_paths.update(ROOT/'tests'/(name+'.lua') for name in ('response-model','measured-controller','tilt-response','motion-progress','tilt-flight'))
  source_paths.update(ROOT/'tools'/name for name in ('build-sputnik.py','lua_compact.py','test-sputnik.py','test-sputnik-universal.py','report-sputnik-universal.py','sputnik-universal-twin.lua','test-sputnik-quad-fpv.py','sputnik-quad-fpv-twin.lua','test-sputnik-quad-pwm.py','report-sputnik-quad-pwm.py','verify-sputnik-quad-pwm.py','report-sputnik-quad-campaign.py','test-quad-ringing-diagnostics.py','run-sputnik-quad-campaign.py','quad_campaign_contract.py','sputnik-quad-campaign.lua','analyze-sputnik-quad-ringing.py','sputnik-digital-twin.lua','VerifySputnikLua.java','VerifySputnikClipboard.java','VerifySablePressure.java'))
  for path in sorted(source_paths):
   if path.is_file() and path.name not in ('README.md','AUTOPILOT.md','IMPLEMENTATION-STATUS.md','COMPATIBILITY.md','VEHICLE-PROFILES.md','WIRING-AND-TESTS.md','QUAD-FLIGHT.md','QUAD-FPV.md','LICENSE'):
    entry=zipfile.ZipInfo('sources/'+path.relative_to(ROOT).as_posix(),(2026,10,25,0,0,0));entry.compress_type=zipfile.ZIP_DEFLATED;entry.external_attr=0o644<<16;z.writestr(entry,path.read_bytes())
  for report_name in ('universal-0.2.0','architecture-0.2.1','interface-0.2.2','quad-fpv-0.3.3'):
   reports=BASE/'reports'/report_name
   if reports.exists():
    for path in sorted(reports.rglob('*')):
     if path.is_file() and path.suffix in ('.json','.csv','.md','.log','.png'):
      entry=zipfile.ZipInfo('reports/'+report_name+'/'+path.relative_to(reports).as_posix(),(2026,10,25,0,0,0));entry.compress_type=zipfile.ZIP_DEFLATED;entry.external_attr=0o644<<16;z.writestr(entry,path.read_bytes())
 for previous in out.glob('mintcraft-sputnik-*.zip'):
  if previous!=archive: previous.unlink()
 sums=''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.relative_to(out).as_posix()+'\n' for p in sorted(out.rglob('*')) if p.is_file() and p.name!='SHA256SUMS')
 (out/'SHA256SUMS').write_text(sums)
 print('Sputnik:',len(modules),'pure modules;',len(scripts),'native node scripts;',archive.stat().st_size,'bytes ZIP')
if __name__=='__main__':
 lock=Path(tempfile.gettempdir())/('mintcraft-sputnik-build-'+hashlib.sha256(str(ROOT).encode()).hexdigest()[:20]+'.lock')
 with lock.open('a') as handle:
  fcntl.flock(handle,fcntl.LOCK_EX);main()
