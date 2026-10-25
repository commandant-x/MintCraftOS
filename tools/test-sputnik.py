#!/usr/bin/env python3
"""Test the native distribution in the exact shaded LuaJ runtime from an audited JAR."""
import base64, argparse, hashlib, json, os, pathlib, shutil, subprocess, tempfile, zipfile
ROOT=pathlib.Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser()
parser.add_argument('--cosmonautics-jar',type=pathlib.Path,required=True)
parser.add_argument('--sable-jar',type=pathlib.Path,help='Optional audited Sable JAR for actual pressure-curve oracle')
parser.add_argument('--java-home',type=pathlib.Path)
parser.add_argument('--minecraft-classpath',help='Optional mapped MC 1.21.1 + runtime dependencies for real SNBT parsing')
args=parser.parse_args()
def execute(command): subprocess.run([str(x) for x in command],cwd=ROOT,check=True)
java=str(args.java_home/'bin/java') if args.java_home else shutil.which('java')
javac=str(args.java_home/'bin/javac') if args.java_home else shutil.which('javac')
assert java and javac,'Java 21 JDK required'
execute([shutil.which('python3') or 'python',ROOT/'tools/build-sputnik.py'])
import importlib.util
spec=importlib.util.spec_from_file_location('sputnik_build',ROOT/'tools/build-sputnik.py');builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
assert builder.nbt_utf8_size('a')==1 and builder.nbt_utf8_size('\0')==2 and builder.nbt_utf8_size('é')==2 and builder.nbt_utf8_size('😀')==6
dist=ROOT/'platforms/sputnik/dist'; manifest=json.loads((dist/'manifest.json').read_text())
assert hashlib.sha256(args.cosmonautics_jar.read_bytes()).hexdigest()==manifest['hostJarSha256'],'Different Cosmonautics JAR: audit its APIs before claiming compatibility'
archive=dist/('mintcraft-sputnik-'+manifest['version']+'.zip')
first=archive.read_bytes()
execute([shutil.which('python3') or 'python',ROOT/'tools/build-sputnik.py'])
assert first==archive.read_bytes(),'Non-deterministic distribution'
for name,record in manifest['artifacts'].items():
 data=(dist/name).read_bytes();assert len(data)==record['bytes'] and hashlib.sha256(data).hexdigest()==record['sha256']
 if name.endswith('.lua') and not name.startswith('sdk/'):
  assert builder.nbt_utf8_size(data.decode())<=60000,'Unsafe native NBT string size'
 if name.endswith('.clipboard.txt'):
  assert not any(chr(c).isspace() for c in data),'Whitespace rejected by Sputnik native decoder'
  assert base64.b64decode(data,validate=True).startswith(b'{nodes:[')
with tempfile.TemporaryDirectory(prefix='mintcraft-sputnik-') as tmp:
 folder=pathlib.Path(tmp); runtime=folder/'runtime.jar'
 # Strip unrelated compiler services; every interpreter class remains byte-exact.
 with zipfile.ZipFile(args.cosmonautics_jar) as src,zipfile.ZipFile(runtime,'w') as target:
  for name in src.namelist():
   if name.startswith('dev/devce/rocketnautics/shaded/luaj/') and name.endswith('.class'):target.writestr(name,src.read(name))
 execute([javac,'-cp',runtime,'-d',folder,ROOT/'tools/VerifySputnikLua.java'])
 cp=str(folder)+os.pathsep+str(runtime)
 # Check lexical compaction in the actual LuaJ parser, including quoted '--'.
 programs=["local x=1 -- comment\nlocal y=2;return x-y,- -x,.5+1e-2,1 .. 'x'",
  "local s='--literal';local t=[=[long\nstring]=];return s,t,0x10",
  "--[[long comment\n]] return (function(a) return (a or 1)+2 end)(3)",
  "local t={v=2};function t:f(x) return self.v+x end;return t:f(3)",
  "local alpha,beta=2,3;local t={alpha=4;beta=5};return alpha+beta,t.alpha,t.beta"]
 def lua_literal(value):
  eq='='
  while ']'+eq+']' in value: eq+='='
  return '['+eq+'['+value+']'+eq+']'
 lexical=folder/'lexical.lua'
 lexical.write_text('\n'.join('do local a={assert(load('+lua_literal(program)+'))()} local b={assert(load('+lua_literal(builder.compact(program))+'))()} assert(#a==#b) for i=1,#a do assert(a[i]==b[i],"Lua compaction changed semantics") end end' for program in programs))
 execute([java,'-cp',cp,'VerifySputnikLua',lexical])
 architecture_bootstrap=folder/'architecture-bootstrap.lua'
 architecture_graphs=[]
 scripts=builder.native_universal();scripts['typewriter']=(dist/'mintcraft-typewriter.lua').read_text();scripts['autopilot-control']=(dist/'mintcraft-autopilot-control.lua').read_text()
 for slug,record in manifest['architectureGraphs'].items():
  nodes,edges=builder.architecture_graph(scripts,builder.source(builder.BASE/'src/test-enable.lua'),record['profile'],record['groups'],slug,{'quad':'Quad','balloon':'Ballon','venator':'Venator','helicopter':'Helicoptere'}[slug])
  assert builder.graph_clipboard(nodes,edges)==(dist/record['file']).read_text(),'Graph fixture differs from imported clipboard'
  assert len(nodes)==6+record['groups'] and len(edges)==17+3*record['groups']
  assert sum('transmitWirelessRedstone' in code for _,code,_,_ in nodes)==1,'More than one physical writer'
  bus=next(code for name,code,_,_ in nodes if name==slug+'-groups')
  assert len(builder.pins(bus)['input'])==2*record['groups'],'Unused group pins returned'
  graph='{slug='+json.dumps(slug)+',profile='+str(record['profile'])+',groups='+str(record['groups'])+',nodes={'+','.join('{name='+json.dumps(n)+',code='+lua_literal(c)+'}' for n,c,x,y in nodes)+'},edges={'+','.join('{'+','.join(json.dumps(v) for v in edge)+'}' for edge in edges)+'}}'
  architecture_graphs.append(graph)
 architecture_bootstrap.write_text('MINTCRAFT_ARCHITECTURE_GRAPHS={'+','.join(architecture_graphs)+'}\n')
 execute([java,'-cp',cp,'VerifySputnikLua',architecture_bootstrap,'platforms/sputnik/tests/architecture-graphs.lua'])
 readable=folder/'native-readable.lua';readable.write_text(builder.native_universal()['autopilot-control'])
 equivalence=folder/'equivalence-bootstrap.lua';equivalence.write_text('MINTCRAFT_UNCOMPACTED='+json.dumps(str(readable))+'\n')
 execute([java,'-cp',cp,'VerifySputnikLua',equivalence,'platforms/sputnik/tests/runtime.lua','platforms/sputnik/tests/drive-mixer.lua','platforms/sputnik/tests/bank-probe.lua','platforms/sputnik/tests/bank-runtime.lua','platforms/sputnik/tests/typewriter.lua','platforms/sputnik/tests/quad-control.lua','platforms/sputnik/tests/aero-physics.lua','platforms/sputnik/tests/link-test.lua','platforms/sputnik/tests/quad-graph.lua','platforms/sputnik/tests/architecture-selector.lua','platforms/sputnik/tests/universal-flight.lua','platforms/sputnik/tests/universal-native.lua'])
 # Prevent the low-inertia resonance from returning behind a favourable plant.
 twin_bootstrap=folder/'twin-bootstrap.lua'
 twin_bootstrap.write_text('MINTCRAFT_TWIN_OUTPUT='+json.dumps(str(folder))+'\n'
  +'MINTCRAFT_TWIN_PROFILE={mass=32,armX=3,armZ=5,height=1,ix=250,iy=400,iz=230}\n'
  +'MINTCRAFT_TWIN_CASES={"inertia_quarter","inertia_eighth","inertia_quarter_delay2","held_forward_20s","course_left_arc","steer_at_rest"}\nMINTCRAFT_TWIN_ASSERT=true\n')
 execute([java,'-cp',cp,'VerifySputnikLua',twin_bootstrap,'tools/sputnik-digital-twin.lua'])
 # Regression gate for the new universal controller, including heterogeneous PWM.
 universal=folder/'universal-bootstrap.lua'
 universal.write_text('MINTCRAFT_UNIVERSAL_PROFILES={1,5}\nMINTCRAFT_UNIVERSAL_CASES={"hover","mass","cruise"}\nMINTCRAFT_UNIVERSAL_ASSERT=true\n')
 execute([java,'-cp',cp,'VerifySputnikLua',universal,'tools/sputnik-universal-twin.lua'])
 # Modular bearings must retain their separate force law and damping under travel.
 twin_bootstrap.write_text('MINTCRAFT_TWIN_OUTPUT='+json.dumps(str(folder))+'\n'
  +'MINTCRAFT_TWIN_PROFILE={mass=32,armX=3,armZ=5,height=1,ix=250,iy=400,iz=230,sails={12,12,12,12}}\n'
  +'MINTCRAFT_TWIN_CASES={"tilt_pitch_5deg","held_forward_20s","mass_loss_15percent"}\nMINTCRAFT_TWIN_ASSERT=true\n')
 execute([java,'-cp',cp,'VerifySputnikLua',twin_bootstrap,'tools/sputnik-digital-twin.lua'])
 bootstrap=folder/'bootstrap.lua'
 text="getUniverseTime=function() return 0 end\nlocal sdk=assert(loadfile('platforms/sputnik/dist/sdk/mintcraft-library.lua'))()\nlocal host=require\nlocal included={\n"
 text+=''.join('['+json.dumps(name)+']=true,\n' for name in manifest['modules'])
 text+="}\nrequire=function(name) if included[name] then return sdk(name) end return host(name) end\n"
 bootstrap.write_text(text)
 execute([java,'-cp',cp,'VerifySputnikLua',bootstrap,*['tests/'+name+'.lua' for name in ('response-model','measured-controller','tilt-response','motion-progress','tilt-flight')]])
 if args.minecraft_classpath:
  if args.sable_jar:
   audit=json.loads((ROOT/'platforms/sputnik/profiles/aeronautics-1.3.2-defaults.json').read_text())
   assert hashlib.sha256(args.sable_jar.read_bytes()).hexdigest()==audit['jars']['sable-neoforge-1.21.1-2.0.6.jar'],'Different Sable physics JAR'
   execute([javac,'-d',folder,ROOT/'tools/VerifySablePressure.java'])
   actual=subprocess.check_output([java,'-cp',str(folder)+os.pathsep+args.minecraft_classpath+os.pathsep+str(args.sable_jar),'VerifySablePressure'],cwd=ROOT)
   assert actual==(ROOT/'platforms/sputnik/tests/fixtures/sable-pressure.csv').read_bytes(),'Actual Sable pressure oracle changed'
  execute([javac,'-proc:none','-cp',args.minecraft_classpath,'-d',folder,ROOT/'tools/VerifySputnikClipboard.java'])
  pairs=[]
  for name in ('autopilot-control','mount-group','mount-bus','mount-setup','flight-commands','local-map','architecture-selector','flight-telemetry','link-test','quad-control','typewriter','import-test','dashboard','vehicle-mixer','drive-mixer','bank-test','test-sequencer','test-enable','link-gateway','numeric-radio'):
   base='platforms/sputnik/dist/mintcraft-'+name;pairs.extend([base+'.clipboard.txt',base+'.lua'])
  pairs.extend(['platforms/sputnik/dist/mintcraft-two-bank-tests.clipboard.txt','@graph'])
  pairs.extend(['platforms/sputnik/dist/mintcraft-flight-audit.clipboard.txt','@graph:2:1'])
  pairs.extend(['platforms/sputnik/dist/mintcraft-quad-flight.clipboard.txt','@graph:7:17'])
  pairs.extend(['platforms/sputnik/dist/mintcraft-autopilot.clipboard.txt','@graph:16:46'])
  for record in manifest['architectureGraphs'].values():
   pairs.extend(['platforms/sputnik/dist/'+record['file'],'@graph:'+str(record['nodes'])+':'+str(record['connections'])])
  execute([java,'-Dmintcraft.sputnik.payload=true','-cp',str(folder)+os.pathsep+args.minecraft_classpath+os.pathsep+str(args.cosmonautics_jar),'VerifySputnikClipboard',*pairs])
print('Sputnik distribution, deterministic build, hashes, actual LuaJ runtime and portable physics passed; no Minecraft world test performed')
