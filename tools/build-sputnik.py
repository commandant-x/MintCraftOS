#!/usr/bin/env python3
"""Build stock Sputnik Lua and its actual Base64/SNBT clipboard format; no downloads."""
from pathlib import Path
import base64, hashlib, json, re, struct, uuid, zipfile
ROOT=Path(__file__).resolve().parent.parent
BASE=ROOT/'platforms/sputnik'
MODULES=['system.ascendancy.contracts']+['system.navigation.'+name for name in (
 'geometry','state_estimator','authority','response_model','measured_controller','closed_loop_qualification',
 'output_characterization','tilt_response','known_flight','motion_progress',
 'altitude_model','altitude_sweep','sweep_progress','autopilot')]
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
def clipboard(name,code):
 ident=uuid.uuid5(uuid.NAMESPACE_URL,'https://github.com/commandant-x/MintCraftOS/sputnik/'+name)
 numbers=','.join(str(v) for v in struct.unpack('>4i',ident.bytes))
 node='{id:[I;'+numbers+'],typeId:"rocketnautics:lua_script",title:'+quote('MintCraft '+name)+',x:40,y:40,inputs:[],outputs:[],elements:[],customData:{code:'+quote(code)+'}}'
 return base64.b64encode(('{nodes:['+node+'],conns:[]}').encode()).decode()+'\n'
def main():
 out=BASE/'dist';out.mkdir(exist_ok=True)
 prefix,modules=bundle()
 scripts={'dashboard':prefix+source(BASE/'src/dashboard.lua'),'link-gateway':source(BASE/'src/gateway.lua'),'numeric-radio':source(BASE/'src/radio.lua')}
 artifacts={}
 library=prefix+'return makePortableModules()\n';(out/'mintcraft-library.lua').write_text(library)
 artifacts['mintcraft-library.lua']={'bytes':len(library.encode()),'sha256':hashlib.sha256(library.encode()).hexdigest()}
 for name,code in scripts.items():
  assert len(code.encode())<262144,'Node source budget exceeded'
  for suffix,text in [('.lua',code),('.clipboard.txt',clipboard(name,code))]:
   path=out/('mintcraft-'+name+suffix);path.write_text(text,encoding='utf-8')
   artifacts[path.name]={'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
 manifest={'schema':1,'edition':'MintCraft Sputnik','version':'0.1.0','target':'Cosmonautics 26.08.307 / Minecraft 1.21.1',
  'hostJarSha256':'3fd9dac868400905a55164d2c9d74abc2080ae3269ca51e54e1899874945973e',
  'import':'Base64 UTF-8 SNBT, WNodeScreen clipboard nodes/conns','testedInMinecraft':False,
  'qualifiedAutopilot':False,'defaultActuation':False,'modules':modules,'artifacts':artifacts}
 (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 files=sorted(p for p in out.iterdir() if p.is_file() and p.suffix!='.zip' and p.name!='SHA256SUMS')
 archive=out/'mintcraft-sputnik-0.1.0.zip'
 with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  for path in files:
   entry=zipfile.ZipInfo(path.name,(2026,10,24,0,0,0));entry.compress_type=zipfile.ZIP_DEFLATED;entry.external_attr=0o644<<16
   z.writestr(entry,path.read_bytes())
  for name in ('README.md','COMPATIBILITY.md'):
   path=BASE/name
   if path.exists():
    entry=zipfile.ZipInfo(name,(2026,10,24,0,0,0));entry.compress_type=zipfile.ZIP_DEFLATED;entry.external_attr=0o644<<16;z.writestr(entry,path.read_bytes())
 sums=''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name+'\n' for p in sorted(out.iterdir()) if p.is_file() and p.name!='SHA256SUMS')
 (out/'SHA256SUMS').write_text(sums)
 print('Sputnik:',len(modules),'pure modules;',len(scripts),'native node scripts;',archive.stat().st_size,'bytes ZIP')
if __name__=='__main__':main()
