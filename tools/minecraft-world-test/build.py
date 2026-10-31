#!/usr/bin/env python3
"""Build the VENATOR copy-only Minecraft fixture from an installed NeoForge server."""
import argparse,os,subprocess,zipfile
from pathlib import Path
HERE=Path(__file__).resolve().parent

def build(server,jdk,work):
 server=server.resolve();jdk=jdk.resolve();work=work.resolve();work.mkdir(parents=True,exist_ok=True)
 jars=list((server/'libraries').rglob('*.jar'))+list((server/'mods').glob('*.jar'))
 if not jars:raise ValueError('Installed NeoForge server libraries and original pack mods are required')
 nested=work/'nested';nested.mkdir(exist_ok=True)
 for jar in jars.copy():
  with zipfile.ZipFile(jar) as z:
   for name in z.namelist():
    if name.startswith('META-INF/jarjar/') and name.endswith('.jar'):
     p=nested/Path(name).name;p.write_bytes(z.read(name));jars.append(p)
 # javac automatically loads compiler services even with -proc:none. The
 # shaded Orekit service entry is broken in this host JAR. Strip only that
 # entry in a compile-only copy, never in the installed runtime mod.
 clean=[]
 for jar in jars:
  with zipfile.ZipFile(jar) as z:
   if 'META-INF/services/com.sun.source.util.Plugin' in z.namelist():
    target=work/('compile-'+jar.name)
    with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED) as out:
     for name in z.namelist():
      if name!='META-INF/services/com.sun.source.util.Plugin':out.writestr(name,z.read(name))
    jar=target
  clean.append(jar)
 clean.sort(key=lambda p:(not p.name.endswith('-srg.jar'),str(p)))
 classes=work/'classes';(classes/'META-INF').mkdir(parents=True,exist_ok=True)
 (classes/'META-INF/neoforge.mods.toml').write_bytes((HERE/'neoforge.mods.toml').read_bytes())
 suffix='.exe' if os.name=='nt' else ''
 subprocess.run([str(jdk/'bin'/('javac'+suffix)),'-proc:none','-cp',os.pathsep.join(map(str,clean)),'-d',str(classes),str(HERE/'MintCraftProbe.java')],check=True)
 target=work/'mintcraft-test-probe.jar'
 subprocess.run([str(jdk/'bin'/('jar'+suffix)),'cf',str(target),'-C',str(classes),'.'],check=True)
 return target
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--server',type=Path,required=True);p.add_argument('--java-home',type=Path,required=True);p.add_argument('--work',type=Path,required=True);a=p.parse_args()
 print(build(a.server,a.java_home,a.work))
