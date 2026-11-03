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
 source={'movements':HERE/'MintCraftProbe.java', 'shocks':HERE/'shocks/MintCraftShockProbe.java', 'viewer':HERE/'shocks/MintCraftViewer.java', 'fleet':HERE/'fleet/MintCraftFleetProbe.java', 'spot':HERE/'spot/SpotTransmissionProbe.java', 'spot-linkage':HERE/'spot-linkage/SpotLinkageProbe.java', 'spot-pivot':HERE/'spot-linkage/SpotPivotProbe.java', 'spot-universal':HERE/'spot-universal/UniversalTransmissionProbe.java', 'spot-leg':HERE/'spot-leg/SpotLegProbe.java', 'spot-leg-powered':HERE/'spot-leg/SpotPoweredLegProbe.java', 'spot-leg-two-drive':HERE/'spot-leg/SpotTwoDriveProbe.java', 'spot-leg-three-drive':HERE/'spot-leg/SpotThreeDriveProbe.java', 'spot-leg-redstone':HERE/'spot-leg/SpotRedstoneLegProbe.java', 'spot-leg-redstone-slow':HERE/'spot-leg/SpotRedstoneSlowLegProbe.java', 'spot-leg-reload':HERE/'spot-leg-reload/SpotReloadProbe.java', 'spot-leg-reload-drive':HERE/'spot-leg-reload/SpotReloadDriveProbe.java', 'spot-leg-configured':HERE/'spot-leg/SpotConfiguredLegProbe.java', 'spot-leg-counterweight':HERE/'spot-leg/SpotCounterweightLegProbe.java', 'spot-leg-balanced-reversing':HERE/'spot-leg/SpotBalancedReversingProbe.java', 'spot-leg-ticket-release':HERE/'spot-leg-reload/SpotTicketReleaseProbe.java', 'spot-leg-balanced-reload':HERE/'spot-leg-reload/SpotReloadBalancedReverseProbe.java', 'spot-leg-ground':HERE/'spot-leg/SpotGroundContactProbe.java', 'spot-leg-support':HERE/'spot-leg/SpotSupportedLegProbe.java', 'spot-leg-guided':HERE/'spot-leg/SpotGuidedLegProbe.java', 'spot-quadruped':HERE/'spot-quadruped/SpotQuadrupedProbe.java', 'spot-quadruped-reload':HERE/'spot-quadruped/SpotQuadrupedReloadProbe.java', 'spot-quadruped-stand':HERE/'spot-quadruped/SpotQuadrupedStandProbe.java', 'spot-quadruped-cleanup':HERE/'spot-quadruped/SpotQuadrupedCleanupProbe.java', 'spot-quadruped-step':HERE/'spot-quadruped/SpotQuadrupedStepProbe.java', 'spot-quadruped-gait':HERE/'spot-quadruped/SpotQuadrupedGaitProbe.java', 'spot-quadruped-gait-tuned':HERE/'spot-quadruped/SpotQuadrupedGaitTunedProbe.java', 'spot-quadruped-loaded-drive':HERE/'spot-quadruped/SpotQuadrupedLoadedDriveProbe.java', 'spot-quadruped-gait-long':HERE/'spot-quadruped/SpotQuadrupedGaitLongProbe.java', 'spot-quadruped-sputnik':HERE/'spot-quadruped/SpotQuadrupedSputnikProbe.java', 'spot-quadruped-sputnik-ui':HERE/'spot-quadruped/SpotQuadrupedSputnikUiProbe.java', 'spot-quadruped-sputnik-reload':HERE/'spot-quadruped/SpotQuadrupedSputnikReloadProbe.java', 'spot-quadruped-sputnik-replay':HERE/'spot-quadruped/SpotQuadrupedSputnikReplayProbe.java', 'spot-quadruped-course':HERE/'spot-quadruped/SpotQuadrupedCourseProbe.java', 'spot-quadruped-course-speed':HERE/'spot-quadruped/SpotQuadrupedCourseSpeedProbe.java'}[fixture]
 manifest=HERE/'shocks/viewer.mods.toml' if fixture=='viewer' else HERE/'neoforge.mods.toml'
 (classes/'META-INF/neoforge.mods.toml').write_bytes(manifest.read_bytes())
 suffix='.exe' if os.name=='nt' else ''
 subprocess.run([str(jdk/'bin'/('javac'+suffix)),'-proc:none','-cp',os.pathsep.join(map(str,clean)),'-d',str(classes),str(source)]+([str(HERE/'fleet/SpeedCampaign.java')] if fixture=='fleet' else []),check=True)
 target=work/('mintcraft-viewer.jar' if fixture=='viewer' else 'mintcraft-test-probe.jar')
 subprocess.run([str(jdk/'bin'/('jar'+suffix)),'cf',str(target),'-C',str(classes),'.'],check=True)
 return target
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--server',type=Path,required=True);p.add_argument('--java-home',type=Path,required=True);p.add_argument('--work',type=Path,required=True);p.add_argument('--fixture',choices=['movements','shocks','viewer','fleet','spot','spot-linkage','spot-pivot','spot-universal','spot-leg','spot-leg-powered','spot-leg-two-drive','spot-leg-three-drive','spot-leg-redstone','spot-leg-redstone-slow','spot-leg-reload','spot-leg-reload-drive','spot-leg-configured','spot-leg-counterweight','spot-leg-balanced-reversing','spot-leg-ticket-release','spot-leg-balanced-reload','spot-leg-ground','spot-leg-support','spot-leg-guided','spot-quadruped','spot-quadruped-reload','spot-quadruped-stand','spot-quadruped-cleanup','spot-quadruped-step','spot-quadruped-gait','spot-quadruped-gait-tuned','spot-quadruped-loaded-drive','spot-quadruped-gait-long','spot-quadruped-sputnik','spot-quadruped-sputnik-ui','spot-quadruped-sputnik-reload','spot-quadruped-sputnik-replay','spot-quadruped-course','spot-quadruped-course-speed'],default='movements');p.add_argument('--client',type=Path);a=p.parse_args()
 print(build(a.server,a.java_home,a.work,a.fixture,a.client))
