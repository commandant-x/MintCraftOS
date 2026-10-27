#!/usr/bin/env python3
"""Archive and plot every native load-change movement, including failures."""
import argparse,collections,hashlib,json,zipfile,importlib.util
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
spec=importlib.util.spec_from_file_location('plots',Path(__file__).with_name('report-sputnik-quad-campaign.py'));plots=importlib.util.module_from_spec(spec);spec.loader.exec_module(plots)
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--work',type=Path,required=True);a=p.parse_args();out=a.output;work=a.work
 m=json.loads((out/'manifest.json').read_text());current=m['version'];previous,baseline={'0.3.4':('0.3.3','01af264048eb62bea330778bfc574b7a283adf44b432dc89897e61594940f1d9'),'0.3.5':('0.3.4','bf7b3e3316158a2a5c35c9c32bfee443101b3bb81d6f2d3c99e31a141044c150')}[current];assert m['sources']['baseline']==baseline;results=json.loads((out/'results.json').read_text())['results'];assert len(results)==72
 folder=work/'plots';folder.mkdir(exist_ok=True)
 for state in m['states']:
  f=state['fixture'];path=folder/(f['id']+'.pdf')
  with PdfPages(path) as pdf:
   for case in state['cases']:
    fig,axes=plt.subplots(4,1,figsize=(11.7,8.3),sharex=True)
    labels=[]
    for controller,color in [('baseline','#b33b32'),('fixed','#1676b3')]:
     r=next(r for r in results if (r['fixture'],r['controller'],r['movement'])==(f['id'],controller,case));assert r['trace'];trace=work/'results'/r['trace'];assert digest(trace)==r['trace_sha256'];d=plots.traces(trace);t=d['t'];labels.append(controller+': '+r['status'])
     axes[0].plot(t,d['y']-d['target_y'],lw=.7,color=color,label=(previous if controller=='baseline' else current)+' '+r['status'])
     axes[1].plot(t,d['tilt'],lw=.7,color=color)
     axes[2].plot(t,(d['vx']**2+d['vz']**2)**.5,lw=.7,color=color)
     for i in range(1,5):axes[3].plot(t,d['u'+str(i)],lw=.3,color=color,alpha=.5)
    for ax,title in zip(axes,['Erreur altitude (m)','Inclinaison (°)','Vitesse horizontale (m/s)','Quatre commandes 0–15']):
     ax.set_ylabel(title);ax.grid(alpha=.25)
     for ep in f['episodes']:ax.axvline(ep['start'],color='#777777',ls='--',lw=.5)
     if case!='hover':ax.axvspan(5,10,color='#dddd66',alpha=.16)
    axes[0].axhspan(-1,1,color='#bbbbbb',alpha=.2);axes[0].legend();axes[-1].set(xlim=(0,60),xlabel='Temps (s)');fig.suptitle(f['id']+' / '+case+' — source physique 256 RPM');fig.tight_layout(rect=(0,0,1,.95));pdf.savefig(fig)
    if f['id']=='added-far-and-dropped' and case=='hover':fig.savefig(out/'load-change-comparison.png',dpi=140)
    plt.close(fig)
 archives=[]
 for name,paths in [('native-com-traces.zip',[(p,'traces/'+p.relative_to(work/'results').as_posix()) for p in sorted((work/'results').rglob('*')) if p.is_file() and p.name!='bootstrap.lua']+[(p,'frozen-sources/'+p.name) for p in sorted((work/'snapshots').iterdir())]+[(out/p,p) for p in ('manifest.json','results.json')]),('native-com-plots.zip',[(p,'plots/'+p.name) for p in sorted(folder.glob('*.pdf'))])]:
  target=out/name
  with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
   for path,arc in paths:z.write(path,arc)
  assert target.stat().st_size<95000000;archives.append(target)
 n=lambda v:'—' if v is None else f'{v:.2f}'
 lines=['# Rééquilibrage quad 0.3.4 — charge décentrée','', 'Le correctif estime un déséquilibre de couple à partir des commandes déjà émises et des accélérations angulaires observées. Il ajuste les bras de levier effectifs dans l’allocation et conserve la consigne verticale. Aucun balayage, aucune impulsion de calibration, aucune lecture fictive du centre de masse. La moyenne de modulation est transportée lors des variations de masse et d’inertie. Le solveur utilise désormais toute la famille de répartitions bornées, plutôt que de refuser une répartition de norme minimale négative alors qu’une autre solution existe.','', '![Ajout puis retrait de charge](load-change-comparison.png)','', '## Protocole et critères','', '12 montages × maintien, avance/freinage et avance-gauche × deux versions = 72 scénarios, interpréteur LuaJ réel de Cosmonautics 26.08.307, mécanique indépendante à 200 Hz, contrôle à 20 Hz, 60 s par essai. Source 256 RPM et mêmes transmissions entières 0–15. Les charges ponctuelles modifient réellement masse, centre et tenseur complet selon le théorème des axes parallèles. Seuls la masse et les trois termes diagonaux sont transmis au contrôleur, avec pose et vitesse de l’origine fixe du véhicule ; jamais le centre réel ni les termes croisés. La vitesse exposée est la différence de poses fraîches à 20 Hz.','', 'Une modification instantanée de masse conserve pose, vitesse et vitesse angulaire du châssis, sans impulsion de collision. La rampe est une succession de redistributions de masse suivant cette convention ; ce n’est pas une simulation de déplacement interne avec conservation du moment, ni un solveur de corde ou un essai Minecraft.','', 'Le succès COM requiert la simulation complète, 1 201 observations espacées de 0,05 s, une altitude demandée inchangée, puis après chaque changement/fin de commande : 20 observations successives avec |Vy| ≤0,1 m/s, vitesse horizontale ≤0,2 m/s, inclinaison ≤5° et erreur de hauteur ≤1 m, obtenues en 15 s au plus. Les cinq dernières secondes de chaque épisode doivent aussi conserver hauteur <1 m, inclinaison <5° et RMS des vitesses verticale/horizontale <0,2 m/s. Un mouvement demandé doit produire le déplacement signé attendu. Les anciens critères complets restent publiés séparément dans `historical` ; un succès COM ne les remplace pas. Toutes les excursions figurent ci-dessous.','', '## Résultats','', '| Version | Succès COM | Échecs COM | Succès aux anciens critères |','| --- | ---: | ---: | ---: |']
 for c in ('baseline','fixed'):
  rr=[r for r in results if r['controller']==c];lines.append(f"| {'0.3.3' if c=='baseline' else '0.3.4'} | {sum(r['status']=='PASS' for r in rr)} | {sum(r['status']=='FAIL' for r in rr)} | {sum(r['historical']['status']=='PASS' for r in rr)} |")
 lines+=['', '| Montage | Version | Mouvement | COM | Excursion hauteur max m | Inclinaison max ° | 20 observations stables après chaque épisode (s) | Défauts COM |','| --- | --- | --- | --- | ---: | ---: | --- | --- |']
 for r in results:
  metrics=r['historical']['metrics'];lines.append('| '+' | '.join([r['fixture'],r['controller'],r['movement'],r['status'],n(metrics.get('transient_height_peak')),n(metrics.get('max_tilt')),', '.join(n(e['stationary20_seconds']) for e in r['episodes']),', '.join(k for k,v in r['checks'].items() if not v) or '—'])+' |')
 lines+=['', '## Limites','', 'Le centre hors du polygone des hélices est volontairement irréalisable et reste un échec. Les montages avec forte hétérogénéité, délais, faibles marges de poussée ou changement pendant une manœuvre peuvent conserver des excursions et des échecs. L’estimation est un biais effectif : elle ne prouve pas un centre de masse mesuré ou une pale disparue. La position fournie par Sputnik n’est pas garantie au centre de masse ; sa rotation peut affecter l’altitude affichée. L’estimation évite d’apprendre un surpoids durant les accélérations angulaires importantes.','', 'Le maintien ne peut être garanti pendant un retournement ou si la charge dépasse l’autorité disponible. Les autres architectures et le contrôleur standard ne sont pas modifiés. Voir aussi la [campagne de non-régression](../quad-campaign-0.3.4/README.md).','', '## Reproduction','', '`tools/test-sputnik-quad-com.py --help`, puis `tools/report-sputnik-quad-com.py` et `tools/verify-sputnik-quad-com.py`. Le fichier Lua 0.3.3 de référence doit être fourni explicitement. Les deux sources réellement exécutées, les critères et la mécanique sont gelés dans l’archive. La validation distincte de l’import SNBT/LuaJ est consignée dans le résumé de livraison.','']
 content='\n'.join(lines).replace('0.3.4','__CURRENT__').replace('0.3.3',previous).replace('__CURRENT__',current)
 if current=='0.3.5':content=content.replace('L’estimation évite d’apprendre un surpoids durant les accélérations angulaires importantes.','L’effort vertical est désormais appris pendant les oscillations modérées avec son filtrage conservé, afin de ne pas bloquer l’adaptation à une charge suspendue. Une erreur de modèle peut encore contaminer cette estimation.').replace('Le correctif estime un déséquilibre','Cette régression vérifie que le contrôleur conserve son estimation de déséquilibre').replace('Le solveur utilise désormais','Le solveur continue d’utiliser')
 (out/'README.md').write_text(content.rstrip()+'\n');(out/'artifacts.json').write_text(json.dumps(dict(schema=1,archives={p.name:dict(bytes=p.stat().st_size,sha256=digest(p)) for p in archives},trace_count=sum(r['trace'] is not None for r in results),classified_cases=len(results)),indent=2)+'\n')
 print('Published',len(results),'load-change classifications and 36 comparison plot pages')
if __name__=='__main__':main()
