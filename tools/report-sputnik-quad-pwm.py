#!/usr/bin/env python3
"""Publish fixed-256-RPM native PWM regression with per-movement evidence."""
import argparse,collections,csv,hashlib,importlib.util,json,zipfile
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from quad_campaign_contract import MOVEMENTS
spec=importlib.util.spec_from_file_location('plots',Path(__file__).with_name('report-sputnik-quad-campaign.py'));plots=importlib.util.module_from_spec(spec);spec.loader.exec_module(plots)
ROOT=Path(__file__).resolve().parent.parent

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def number(v):return 'absente' if v is None else f'{v:.2f}'
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--work',type=Path,required=True);a=p.parse_args();out=a.output.resolve();work=a.work.resolve()
 m=json.loads((out/'manifest.json').read_text());data=json.loads((out/'results.json').read_text());rows=data['results'];assert len(rows)==sum(len(s['cases'])*2 for s in m['states'])==82
 fixed=ROOT/'platforms/sputnik/dist/mintcraft-autopilot-quad-fpv.lua';assert digest(fixed)==m['sources']['fixed']
 for r in rows:
  if r['trace']:assert digest(work/'results'/r['trace'])==r['trace_sha256']
 groups=collections.defaultdict(list)
 for r in rows:groups[(r['fixture'],r['controller'])].append(r)
 folder=work/'plots';folder.mkdir(exist_ok=True)
 for key,rr in sorted(groups.items()):
  path=folder/('-'.join(key)+'.pdf');plots.render_pdf(path,rr,work,MOVEMENTS,60)
 # Exact native comparison, fixed physical RPM, first attitude deliberately tilted.
 fig,axes=plt.subplots(2,3,figsize=(15,8),sharex=True)
 for row,case in enumerate(('hover','brake')):
  for controller,color,label in [('baseline','#b62525','0.3.2'),('fixed','#1565b5','0.3.3')]:
   r=next(r for r in rows if r['fixture']=='reference-tilt3' and r['controller']==controller and r['movement']==case)
   d=plots.traces(work/'results'/r['trace']);t=d['t']
   axes[row,0].plot(t,d['y']-d['target_y'],label=label,lw=.8,color=color)
   axes[row,1].plot(t,d['attitude_error'],lw=.8,color=color)
   axes[row,2].plot(t,d['vy'],lw=.8,color=color)
  for col,(ylabel,band) in enumerate([('Erreur hauteur (m)',.3),('Erreur assiette (°)',2),('Vy (m/s)',.2)]):
   ax=axes[row,col];ax.axhspan(0 if col==1 else -band,band,color='#cccccc',alpha=.4);ax.grid(alpha=.25);ax.set(xlabel='Temps (s)',ylabel=ylabel,xlim=(0,60),title='Maintien' if row==0 else 'W entre 5 et 10 s puis freinage')
   if row==1:ax.axvspan(5,10,color='#dddd66',alpha=.15)
 axes[0,0].legend();fig.suptitle('Même véhicule simulé : 32 kg, 12 voiles, source 256 RPM, départ incliné de 3°\nSeule la modulation change ; aucune modification mécanique ni nouveau gain',fontsize=13);fig.tight_layout(rect=(0,0,1,.92));fig.savefig(out/'fixed-source-transients.png',dpi=150);plt.close(fig)
 archives=[]
 path=out/'native-pwm-traces.zip'
 with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  for file in sorted((work/'results').rglob('*')):
   if file.is_file() and file.name!='bootstrap.lua':z.write(file,'traces/'+file.relative_to(work/'results').as_posix())
  for file in sorted((work/'snapshots').iterdir()):z.write(file,'frozen-sources/'+file.name)
  for name in ('manifest.json','results.json'):z.write(out/name,name)
  z.write(Path(__file__),'frozen-sources/report-sputnik-quad-pwm.py')
 archives.append(path)
 path=out/'native-pwm-plots.zip'
 with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  for file in sorted(folder.glob('*.pdf')):z.write(file,'plots/'+file.name)
 archives.append(path)
 assert all(p.stat().st_size<95000000 for p in archives)
 lines=['# Modulation quad 0.3.3 — correction à 256 RPM inchangés','', 'Le correctif retire uniquement le raccourci qui imposait une sortie commune lorsque les quatre demandes différaient de moins de 0,08 niveau. Ce raccourci effaçait aussi le résidu de couple. Un même quantificateur couplé conserve maintenant les petites corrections et leur moyenne temporelle. Les gains, la géométrie, le régime mécanique et les niveaux 0–15 restent inchangés.','', '**Le banc utilise réellement 256 RPM dans les deux modèles mécaniques**, avec les mêmes masses, inerties et voiles. Le contrôleur ne demande aucune réduction mécanique ni nouvelle saisie. La référence utilise 32 kg, quatre hélices de 12 voiles et les bras X=±3/Z=±5.','', '![Transitions à source identique](fixed-source-transients.png)','', '## Temps de stabilisation durable : référence à 3°','', 'Les bandes du diagnostic sont conservées : hauteur <0,3 m, erreur d’assiette <2°, |Vy|<0,2 m/s, vitesse horizontale <0,3 m/s après commande horizontale. Une seconde stable doit subsister jusqu’à la fin de la trace, sans sortie ultérieure. Ce sont des critères de recherche plus stricts que les anciens seuils finaux. Le chronomètre part de la fin de commande ou de la perturbation.','', '| Mouvement | 0.3.2 s | 0.3.3 s | Sorties après première seconde stable : avant → après |','| --- | ---: | ---: | --- |']
 for case in MOVEMENTS:
  old=next(r for r in rows if r['fixture']=='reference-tilt3' and r['controller']=='baseline' and r['movement']==case)['transient'];new=next(r for r in rows if r['fixture']=='reference-tilt3' and r['controller']=='fixed' and r['movement']==case)['transient']
  lines.append('| '+case+' | '+number(old.get('durable_settling_seconds'))+' | '+number(new.get('durable_settling_seconds'))+' | '+str(old.get('reexits_after_stable_window'))+' → '+str(new.get('reexits_after_stable_window'))+' |')
 lines+=['', 'La récupération inversée reste lente et peut perdre de la hauteur : une amélioration du maintien ne supprime pas cette limite. Le seul mouvement latéral gauche conserve une réexcursion sur la référence. Les graphiques complets montrent toute la simulation, pas seulement la fenêtre finale.','', '## Chaque mouvement et chaque domaine','', '40 scénarios physiques par contrôleur, plus un refus prévol volontaire par contrôleur (départ diagonal à 15°, hors garde initiale ±10° sur les angles observés). Ces deux refus ne constituent pas des vols réussis.','', '| Montage | Contrôleur | Mouvement | Résultat historique | Stabilité durable s | Réexcursions |','| --- | --- | --- | --- | ---: | ---: |']
 for r in rows:
  t=r['transient'];lines.append(f"| {r['fixture']} | {r['controller']} | {r['movement']} | {r['status']} | {number(t.get('durable_settling_seconds'))} | {t.get('reexits_after_stable_window','—')} |")
 lines+=['', '## Domaine et preuves','', 'La référence inclinée passe de 23/24 à 24/24 anciens critères. Les profils à très forte poussée ou avec retard radio conservent des échecs. Cette correction cible une perte de petites commandes dans la modulation ; elle ne qualifie pas tous les montages. Voir aussi [les 576 essais de campagne](../quad-campaign-0.3.3/README.md), qui publient les régressions et les excursions.','', 'Le test unitaire reconstruit la poussée et le couple à partir des RPM demandés par les niveaux entiers et mesure leur moyenne sur 2 048 appels. Un couple de ±0,01 rad/s² doit rester représenté sous le seuil de l’ancien raccourci. Le même test échoue sur 0.3.2 et réussit sur 0.3.3 dans LuaJ. Les résultats constituent une preuve logicielle et synthétique, pas un acquittement physique Link.','', 'Les traces proviennent du véritable interpréteur LuaJ du JAR Cosmonautics audité. Le banc est un corps rigide indépendant à 200 Hz, commande à 20 Hz, avec les hypothèses publiées dans les campagnes précédentes. Aucun essai Minecraft, aucune collision, aucun vrai solveur de joints ou de stress n’est revendiqué.','', 'Reproduction : `tools/test-sputnik-quad-pwm.py --help`, puis `tools/report-sputnik-quad-pwm.py --help`. Le test nécessite un JDK 21, le JAR audité et un fichier Lua de référence 0.3.2 fourni explicitement ; les contrôleurs et entrées exacts sont conservés dans les archives.','', '## Archives','']
 for path in archives:lines.append(f'- [{path.name}]({path.name}) : {path.stat().st_size/1e6:.1f} Mo.')
 (out/'README.md').write_text('\n'.join(lines)+'\n')
 record=dict(schema=1,archives={p.name:dict(bytes=p.stat().st_size,sha256=digest(p)) for p in archives},trace_count=sum(r['trace'] is not None for r in rows),classified_cases=len(rows),controllers=m['sources'],scope='Fixed physical 256 RPM, native LuaJ simulation, not Minecraft qualification')
 (out/'artifacts.json').write_text(json.dumps(record,indent=2)+'\n')
 print('Published fixed-source regression',record['classified_cases'],'cases /',record['trace_count'],'traces')
if __name__=='__main__':main()
