from pathlib import Path
import os,subprocess,zipfile
root=Path('/workspace/MintCraftOS');w=root/'work/fleet-expansion';server=w/'server';build=w/'build-expanded';jdk=Path('/workspace/.mintcraft-setup/jdk/usr/lib/jvm/java-21-openjdk-amd64/bin');out=w/'codec';out.mkdir(exist_ok=True)
jars=list((server/'libraries').rglob('*.jar'))+list((server/'mods').glob('*.jar'))+list((build/'nested').glob('*.jar'))
clean=[]
for p in jars:
 q=build/('compile-'+p.name)
 if q.exists():p=q
 clean.append(p)
clean.sort(key=lambda p:(not p.name.endswith('-srg.jar'),str(p)))
cp=os.pathsep.join(map(str,clean))
subprocess.run([str(jdk/'javac'),'-proc:none','-cp',cp,'-d',str(out),str(root/'tools/VerifySputnikClipboard.java')],check=True)
args=[]
for p in sorted((root/'platforms/sputnik/reports/native-fleet-0.4.2').glob('*.clipboard.txt')):args.extend([str(p),'@graph:7:34'])
subprocess.run([str(jdk/'java'),'-Dmintcraft.sputnik.payload=true','-cp',str(out)+os.pathsep+cp,'VerifySputnikClipboard',*args],cwd=root,check=True)
