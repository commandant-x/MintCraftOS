#!/usr/bin/env python3
"""Build stock Sputnik Lua and its actual Base64/SNBT clipboard format; no downloads."""
from pathlib import Path
import base64, hashlib, json, re, struct, uuid, zipfile
ROOT=Path(__file__).resolve().parent.parent
BASE=ROOT/'platforms/sputnik'
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
def graph_clipboard(nodes,edges):
 identifiers={name:uuid.uuid5(uuid.NAMESPACE_URL,'https://github.com/commandant-x/MintCraftOS/sputnik/'+name) for name,code,x,y in nodes}
 metadata={name:pins(code) for name,code,x,y in nodes}
 records=[]
 for name,code,x,y in nodes:
  assert nbt_utf8_size(code)<=60000,'Unsafe native node size'
  records.append('{id:'+uuid_tag(identifiers[name])+',typeId:"rocketnautics:lua_script",title:'+quote('MintCraft '+name)+',x:'+str(x)+',y:'+str(y)+',inputs:'+pin_tags(metadata[name]['input'],'INPUT')+',outputs:'+pin_tags(metadata[name]['output'],'OUTPUT')+',elements:[],customData:{code:'+quote(code)+'}}')
 connections=[]
 for src,out,tgt,inp in edges:
  source_index=[v[0] for v in metadata[src]['output']].index(out)
  target_index=[v[0] for v in metadata[tgt]['input']].index(inp)
  connections.append('{src:'+uuid_tag(identifiers[src])+',srcP:'+str(source_index)+',tgt:'+uuid_tag(identifiers[tgt])+',tgtP:'+str(target_index)+'}')
 text='{nodes:['+','.join(records)+'],conns:['+','.join(connections)+']}'
 return base64.b64encode(text.encode()).decode()
def clipboard(name,code): return graph_clipboard([(name,code,40,40)],[])
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
 scripts={'link-test':source(BASE/'src/link-test.lua'),'quad-control':quad,'typewriter':source(BASE/'src/typewriter.lua'),'vehicle-mixer':vehicle,'bank-test':bank,'test-sequencer':sequencer,'test-enable':consent,'drive-mixer':mixer,'import-test':source(BASE/'src/import-test.lua'),'dashboard':source(BASE/'src/dashboard.lua'),'link-gateway':source(BASE/'src/gateway.lua'),'numeric-radio':source(BASE/'src/radio.lua')}
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
 quad_nodes=[('quad-enable',consent,20,40),('quad-keyboard',scripts['typewriter'],350,40),('quad-controller',quad,1100,40)]
 quad_edges=[('quad-enable','Binding','quad-controller','Enable binding'),('quad-keyboard','Bindings','quad-controller','Keyboard bindings'),('quad-enable','Enable','quad-keyboard','Enable'),('quad-enable','Enable','quad-controller','Flight Enable')]
 for pin in ('Forward demand','Left demand','Vertical demand','Commands valid'):
  quad_edges.append(('quad-keyboard',pin,'quad-controller',pin))
 path=out/'mintcraft-quad-flight.clipboard.txt'
 path.write_text(graph_clipboard(quad_nodes,quad_edges),encoding='utf-8')
 artifacts[path.name]={'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
 manifest={'schema':1,'edition':'MintCraft Sputnik','version':'0.1.9','target':'Cosmonautics 26.08.307 / Minecraft 1.21.1',
  'hostJarSha256':'3fd9dac868400905a55164d2c9d74abc2080ae3269ca51e54e1899874945973e',
  'import':'Base64 UTF-8 SNBT, WNodeScreen clipboard nodes/conns','testedInMinecraft':False,
  'qualifiedAutopilot':False,'defaultActuation':False,'nativeNodeModifiedUtf8Budget':60000,
  'developerLibraryImportableAsSingleNode':False,'nodeModifiedUtf8Bytes':{name:nbt_utf8_size(code) for name,code in scripts.items()},'modules':modules,'artifacts':artifacts}
 (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 files=sorted(p for p in out.rglob('*') if p.is_file() and p.suffix!='.zip' and p.name!='SHA256SUMS')
 archive=out/'mintcraft-sputnik-0.1.9.zip'
 with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  for path in files:
   entry=zipfile.ZipInfo(path.relative_to(out).as_posix(),(2026,10,24,0,0,0));entry.compress_type=zipfile.ZIP_DEFLATED;entry.external_attr=0o644<<16
   z.writestr(entry,path.read_bytes())
  for name in ('README.md','COMPATIBILITY.md','VEHICLE-PROFILES.md','WIRING-AND-TESTS.md','QUAD-FLIGHT.md','LICENSE'):
   path=ROOT/name if name=='LICENSE' else BASE/name
   if path.exists():
    entry=zipfile.ZipInfo(name,(2026,10,24,0,0,0));entry.compress_type=zipfile.ZIP_DEFLATED;entry.external_attr=0o644<<16;z.writestr(entry,path.read_bytes())
 sums=''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.relative_to(out).as_posix()+'\n' for p in sorted(out.rglob('*')) if p.is_file() and p.name!='SHA256SUMS')
 (out/'SHA256SUMS').write_text(sums)
 print('Sputnik:',len(modules),'pure modules;',len(scripts),'native node scripts;',archive.stat().st_size,'bytes ZIP')
if __name__=='__main__':main()
