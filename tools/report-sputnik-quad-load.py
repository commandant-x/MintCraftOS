#!/usr/bin/env python3
"""Publish complete native suspended-load traces and paired per-movement plots."""
import argparse,collections,hashlib,importlib.util,json,zipfile
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
spec=importlib.util.spec_from_file_location('plots',Path(__file__).with_name('report-sputnik-quad-campaign.py'));plots=importlib.util.module_from_spec(spec);spec.loader.exec_module(plots)
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--work',type=Path,required=True);a=p.parse_args();out=a.output;work=a.work
 m=json.loads((out/'manifest.json').read_text());results=json.loads((out/'results.json').read_text())['results'];assert len(results)==96;assert m['sources']['baseline']=='bf7b3e3316158a2a5c35c9c32bfee443101b3bb81d6f2d3c99e31a141044c150'
 folder=work/'plots';folder.mkdir(exist_ok=True)
 for state in m['states']:
  f=state['fixture']
  with PdfPages(folder/(f['id']+'.pdf')) as pdf:
   for case in state['cases']:
    fig,axes=plt.subplots(3,2,figsize=(11.7,8.3),sharex=True)
    for controller,color in [('baseline','#b33b32'),('fixed','#1676b3')]:
     r=next(r for r in results if (r['fixture'],r['controller'],r['movement'])==(f['id'],controller,case));trace=work/'results'/r['trace'];assert digest(trace)==r['trace_sha256'];d=plots.traces(trace);t=d['t'];label=('0.3.4' if controller=='baseline' else m['version'])+' '+r['status']
     values=[d['y']-d['target_y'],d['tilt'],d['vy'],(d['vx']**2+d['vz']**2)**.5,d['rope_angle']]
     for ax,v in zip(axes.flat,values):ax.plot(t,v,lw=.6,color=color,label=label)
     for i in range(1,5):axes.flat[5].plot(t,d['u'+str(i)],lw=.25,color=color,alpha=.5)
    for ax,title in zip(axes.flat,['Erreur hauteur (m)','Inclinaison (°)','Vy (m/s)','Vitesse horizontale (m/s)','Angle câble / verticale (°)','Quatre commandes 0–15']):
     ax.set_ylabel(title);ax.grid(alpha=.25);ax.axvline(5,color='#777777',ls='--',lw=.5);ax.set_xlim(0,60)
    axes.flat[0].legend(fontsize=7);axes.flat[0].axhspan(-1,1,color='#bbbbbb',alpha=.2);fig.suptitle(f['id']+' / '+case+' — source 256 RPM, charge ajoutée à 5 s');fig.tight_layout(rect=(0,0,1,.95));pdf.savefig(fig)
    if f['id']=='short-rope' and case=='load-swing':fig.savefig(out/'suspended-load-comparison.png',dpi=140)
    plt.close(fig)
 archives=[]
 for name,paths in [('native-load-traces.zip',[(p,'traces/'+p.relative_to(work/'results').as_posix()) for p in sorted((work/'results').rglob('*')) if p.is_file() and p.name!='bootstrap.lua']+[(p,'frozen-sources/'+p.name) for p in sorted((work/'snapshots').iterdir())]+[(out/p,p) for p in ('manifest.json','results.json')]),('native-load-plots.zip',[(p,'plots/'+p.name) for p in sorted(folder.glob('*.pdf'))])]:
  target=out/name
  with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
   for path,arc in paths:z.write(path,arc)
  assert target.stat().st_size<95000000;archives.append(target)
 if (out/'rejected-prototype.zip').exists():archives.append(out/'rejected-prototype.zip')
 n=lambda v:'—' if v is None else f'{v:.2f}'
 lines=['# Quad 0.3.5 — maintien avec charge suspendue','', 'Le retour horizontal au maintien devient moins agressif lorsque le bilan vertical révèle une charge supplémentaire. La correction verticale apprend aussi pendant les mouvements angulaires modérés, avec son filtrage conservé ; elle ne reste plus gelée précisément quand la charge balance. Le freinage vertical est renforcé pour une commande verticale ou un effort extérieur estimé supérieur à 10 % de la gravité ; le gain précédent reste utilisé sans cet effort. La consigne de vitesse n’augmente pas. Les consignes, fréquences, modèle de poussée, régime 256 RPM et niveaux entiers 0–15 restent identiques. Aucun paramètre de corde ou poids suspendu n’est transmis au pilote.','', '![Maintien avec corde courte](suspended-load-comparison.png)','', '## Banc et critères','', '8 montages × 6 mouvements × 2 versions = 96 scénarios à 60 secondes. Commande dans le LuaJ réel de Cosmonautics 26.08.307 à 20 Hz ; mécanique indépendante à 200 Hz. Masses de châssis 32/96 kg, charges 4/12/32 kg, cordes 2/5/10 m, attaches centrées/déportées et angles initiaux 20/40°. Chaque charge est ajoutée à 5 s, y compris pendant une commande. La masse exposée reste celle du châssis : le contrôleur n’accède ni au poids suspendu, ni à l’angle ou la longueur du câble. La position et la vitesse sont celles d’une origine fixe du corps ; la vitesse d’entrée est calculée par différence de positions fraîches à 20 Hz.','', 'Le banc reprend la contrainte unilatérale de câble, les réactions au point d’attache et la projection de dérive des campagnes précédentes. Ce n’est pas le solveur de joints Minecraft, ni une corde multiple ou un objet étendu. Absence de collision/stress/effet de sol. Le moteur physique n’utilise pas l’allocation du contrôleur.','', 'Les critères historiques restent tous actifs : hauteur finale <1 m, RMS <0,5 m, inclinaison finale <5°, vitesse RMS <0,35 m/s, suivi des commandes, freinage et excursions transitoires. Le plafond transitoire historique est de 5 m pour `load-swing` et de 2 m pour les autres mouvements. On ajoute un angle de câble <5° sur les dix dernières secondes et des observations espacées de 0,05 s. Une arrivée dans une bande pendant un instant ne suffit pas. Chaque résultat et chaque échec est conservé.','', '## Résultats','', '| Contrôleur | PASS | FAIL | REFUSED |','| --- | ---: | ---: | ---: |']
 for c in ('baseline','fixed'):
  counts=collections.Counter(r['status'] for r in results if r['controller']==c);lines.append(f"| {'0.3.4' if c=='baseline' else m['version']} | {counts['PASS']} | {counts['FAIL']} | {counts['REFUSED']} |")
 lines+=['', '| Montage | Version | Mouvement | Résultat | Pic hauteur m | Inclinaison finale max ° | Câble final max ° | Échecs |','| --- | --- | --- | --- | ---: | ---: | ---: | --- |']
 for r in results:
  v=r['metrics'];lines.append('| '+' | '.join([r['fixture'],r['controller'],r['movement'],r['status'],n(v.get('transient_height_peak')),n(v.get('tail_tilt')),n(v.get('tail_cable_peak')),', '.join(r['failures']) or '—'])+' |')
 lines+=['', '## Limites et reproduction','', 'Une réussite synthétique ne garantit pas la stabilité du montage montré en jeu. Les défauts de géométrie déclarée, délais, marges de poussée et plusieurs cordes/charges articulées ne sont pas identifiés automatiquement. Le pilote estime un effort extérieur ; il n’annonce pas connaître la masse réelle de la charge ni sa cause. Les paramètres d’architecture restent nécessaires et la fermeture de l’éditeur n’est pas un arrêt physique.','', 'Voir la [campagne générale](../quad-campaign-0.3.5/README.md) et ses régressions. Les deux contrôleurs, critères, paramètres mécaniques et traces exactes sont gelés dans les archives. `tools/test-sputnik-quad-load.py`, `tools/report-sputnik-quad-load.py` et `tools/verify-sputnik-quad-load.py` reproduisent et vérifient ces résultats. Le fichier Lua 0.3.4 est fourni explicitement comme référence.']
 lines+=['', 'Le [prototype rejeté](rejected-prototype.zip) conserve ses 24 essais natifs de référence et sources : le gain vertical renforcé sans condition régressait en translation latérale (22/24, inclinaison supérieure à 42°). Il a été remplacé avant livraison. Ce fichier est une preuve de test, pas un graphe à importer.']
 (out/'README.md').write_text('\n'.join(lines).rstrip()+'\n');(out/'artifacts.json').write_text(json.dumps(dict(schema=1,archives={p.name:dict(bytes=p.stat().st_size,sha256=digest(p)) for p in archives},trace_count=sum(r['trace'] is not None for r in results),classified_cases=len(results)),indent=2)+'\n');print('Published',len(results),'load classifications and 48 comparison plot pages')
if __name__=='__main__':main()
