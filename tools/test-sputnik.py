#!/usr/bin/env python3
"""Test the native distribution in the exact shaded LuaJ runtime from an audited JAR."""
import argparse, hashlib, json, os, pathlib, shutil, subprocess, tempfile, zipfile
ROOT=pathlib.Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser()
parser.add_argument('--cosmonautics-jar',type=pathlib.Path,required=True)
parser.add_argument('--java-home',type=pathlib.Path)
parser.add_argument('--minecraft-classpath',help='Optional mapped MC 1.21.1 + runtime dependencies for real SNBT parsing')
args=parser.parse_args()
def execute(command): subprocess.run([str(x) for x in command],cwd=ROOT,check=True)
java=str(args.java_home/'bin/java') if args.java_home else shutil.which('java')
javac=str(args.java_home/'bin/javac') if args.java_home else shutil.which('javac')
assert java and javac,'Java 21 JDK required'
execute([shutil.which('python3') or 'python',ROOT/'tools/build-sputnik.py'])
dist=ROOT/'platforms/sputnik/dist'; manifest=json.loads((dist/'manifest.json').read_text())
assert hashlib.sha256(args.cosmonautics_jar.read_bytes()).hexdigest()==manifest['hostJarSha256'],'Different Cosmonautics JAR: audit its APIs before claiming compatibility'
first=(dist/'mintcraft-sputnik-0.1.0.zip').read_bytes()
execute([shutil.which('python3') or 'python',ROOT/'tools/build-sputnik.py'])
assert first==(dist/'mintcraft-sputnik-0.1.0.zip').read_bytes(),'Non-deterministic distribution'
for name,record in manifest['artifacts'].items():
 data=(dist/name).read_bytes();assert len(data)==record['bytes'] and hashlib.sha256(data).hexdigest()==record['sha256']
with tempfile.TemporaryDirectory(prefix='mintcraft-sputnik-') as tmp:
 folder=pathlib.Path(tmp); runtime=folder/'runtime.jar'
 # Strip unrelated compiler services; every interpreter class remains byte-exact.
 with zipfile.ZipFile(args.cosmonautics_jar) as src,zipfile.ZipFile(runtime,'w') as target:
  for name in src.namelist():
   if name.startswith('dev/devce/rocketnautics/shaded/luaj/') and name.endswith('.class'):target.writestr(name,src.read(name))
 execute([javac,'-cp',runtime,'-d',folder,ROOT/'tools/VerifySputnikLua.java'])
 cp=str(folder)+os.pathsep+str(runtime)
 execute([java,'-cp',cp,'VerifySputnikLua','platforms/sputnik/tests/runtime.lua'])
 bootstrap=folder/'bootstrap.lua'
 text="getUniverseTime=function() return 0 end\nlocal sdk=assert(loadfile('platforms/sputnik/dist/mintcraft-library.lua'))()\nlocal host=require\nlocal included={\n"
 text+=''.join('['+json.dumps(name)+']=true,\n' for name in manifest['modules'])
 text+="}\nrequire=function(name) if included[name] then return sdk(name) end return host(name) end\n"
 bootstrap.write_text(text)
 execute([java,'-cp',cp,'VerifySputnikLua',bootstrap,*['tests/'+name+'.lua' for name in ('response-model','measured-controller','tilt-response','motion-progress','tilt-flight')]])
 if args.minecraft_classpath:
  execute([javac,'-proc:none','-cp',args.minecraft_classpath,'-d',folder,ROOT/'tools/VerifySputnikClipboard.java'])
  pairs=[]
  for name in ('dashboard','link-gateway','numeric-radio'):
   base='platforms/sputnik/dist/mintcraft-'+name;pairs.extend([base+'.clipboard.txt',base+'.lua'])
  execute([java,'-cp',str(folder)+os.pathsep+args.minecraft_classpath,'VerifySputnikClipboard',*pairs])
print('Sputnik distribution, deterministic build, hashes, actual LuaJ runtime and portable physics passed; no Minecraft world test performed')
