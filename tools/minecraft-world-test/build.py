#!/usr/bin/env python3
"""Build the VENATOR copy-only Minecraft fixture from an installed NeoForge server."""
import argparse,os,shutil,subprocess,zipfile
from pathlib import Path
HERE=Path(__file__).resolve().parent

def build(server,jdk,work,fixture='movements',client=None):
 server=server.resolve();jdk=jdk.resolve();work=work.resolve();work.mkdir(parents=True,exist_ok=True)
 jars=list((server/'libraries').rglob('*.jar'))+list((server/'mods').glob('*.jar'))
 if fixture=='viewer':
  if client is None:raise ValueError('--client must name an installed NeoForge client for the viewer fixture')
  jars=list((client.resolve()/'libraries').rglob('*.jar'))+jars
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
 classes=work/'classes'
 if classes.exists():shutil.rmtree(classes)
 (classes/'META-INF').mkdir(parents=True,exist_ok=True)
 source={'movements':HERE/'MintCraftProbe.java', 'shocks':HERE/'shocks/MintCraftShockProbe.java', 'viewer':HERE/'shocks/MintCraftViewer.java', 'fleet':HERE/'fleet/MintCraftFleetProbe.java'}[fixture]
 manifest=HERE/'shocks/viewer.mods.toml' if fixture=='viewer' else HERE/'neoforge.mods.toml'
 (classes/'META-INF/neoforge.mods.toml').write_bytes(manifest.read_bytes())
 suffix='.exe' if os.name=='nt' else ''
 subprocess.run([str(jdk/'bin'/('javac'+suffix)),'-proc:none','-cp',os.pathsep.join(map(str,clean)),'-d',str(classes),str(source)],check=True)
 target=work/('mintcraft-viewer.jar' if fixture=='viewer' else 'mintcraft-test-probe.jar')
 subprocess.run([str(jdk/'bin'/('jar'+suffix)),'cf',str(target),'-C',str(classes),'.'],check=True)
 return target
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--server',type=Path,required=True);p.add_argument('--java-home',type=Path,required=True);p.add_argument('--work',type=Path,required=True);p.add_argument('--fixture',choices=['movements','shocks','viewer','fleet'],default='movements');p.add_argument('--client',type=Path);a=p.parse_args()
 print(build(a.server,a.java_home,a.work,a.fixture,a.client))
