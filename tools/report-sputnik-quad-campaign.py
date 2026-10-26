#!/usr/bin/env python3
"""Publish per-movement criteria, complete traces and one scientific plot page per executed case."""
import argparse,collections,csv,hashlib,inspect,json,math,textwrap,time,zipfile
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
from matplotlib.colors import ListedColormap
import numpy as np
from quad_campaign_contract import MOVEMENTS,CRITERIA,evaluate
ROOT=Path(__file__).resolve().parent.parent

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def number(v):return '—' if v is None else f'{v:.3f}'
def traces(path):
 with path.open() as f: rows=list(csv.DictReader(f))
 return {k:np.asarray([float(r[k]) for r in rows]) for k in rows[0]} if rows else {}
def plot_page(pdf,result,path,protocol,seconds):
 r=result;d=traces(path);fig,axes=plt.subplots(2,3,figsize=(11.7,8.3))
 status=r['status'];color={'PASS':'#147a38','FAIL':'#b62424','REFUSED':'#666666'}[status]
 fig.suptitle(f"{r['fixture']} / {r['controller']} / {r['movement']} — {status}",color=color,fontsize=14)
 fig.text(.05,.925,textwrap.fill(protocol,130),fontsize=8)
 ax=axes.flat[0];ax.plot(d['x'],d['z'],lw=1);ax.scatter([d['x'][0],d['x'][-1]],[d['z'][0],d['z'][-1]],c=['green','red'],s=14);ax.set(xlabel='X monde (m)',ylabel='Z monde (m)',title='Trajectoire réelle, début vert / fin rouge');ax.set_aspect('equal',adjustable='datalim')
 t=d['t'];ax=axes.flat[1];ax.plot(t,d['y'],label='réelle',lw=.9);ax.plot(t,d['target_y'],'--',label='cible acceptée',lw=.8);ax.fill_between(t,d['target_y']-1,d['target_y']+1,color='#b0d7ed',alpha=.35);ax.set(ylabel='Altitude (m)',title='Altitude et bande ±1 m');ax.legend(fontsize=6)
 ax=axes.flat[2]
 for key,label,color in [('pitch','tangage','#1565c0'),('roll','roulis','#c64c14')]:
  ax.plot(t,d[key],label=label,color=color,lw=.7);ax.plot(t,d['target_'+key],ls='--',color=color,lw=.7)
 ax.set(ylabel='Degrés',title='Assiette réelle / cible en pointillé');ax.legend(fontsize=6)
 ax=axes.flat[3]
 for key,label in [('vx','Vx'),('vy','Vy'),('vz','Vz')]:ax.plot(t,d[key],label=label,lw=.7)
 ax.plot(t,4*d['vertical'],'--',label='touche verticale ×4',lw=.7,color='black');ax.set(ylabel='m/s',title='Vitesses et demande verticale');ax.legend(fontsize=6)
 ax=axes.flat[4]
 for i in range(1,5):ax.step(t,d['u'+str(i)],where='post',label=str(i),lw=.45,rasterized=True)
 ax.set(ylim=(-.5,15.5),ylabel='Niveau Link',title='Quatre sorties (0 plein régime / 15 arrêt)');ax.legend(fontsize=6,ncol=4)
 ax=axes.flat[5];ax.plot(t,np.abs(d['y']-d['target_y']),label='erreur hauteur / 1 m',lw=.8);ax.plot(t,d['attitude_error']/5,label='erreur assiette / 5°',lw=.8);ax.axhline(1,color='black',ls='--',lw=.6);ax.set(ylabel='Rapport aux seuils de base',title='Erreurs normalisées (critères détaillés séparés)');ax.legend(fontsize=6)
 for ax in list(axes.flat)[1:]:
  ax.set_xlim(0,seconds);ax.set_xlabel('Temps (s)');ax.axvspan(5,10,color='#b0b0b0',alpha=.15);ax.axvspan(seconds-10,seconds,color='#70c090',alpha=.13)
  if r['movement']=='vertical-cycle':ax.axvspan(15,20,color='#b0b0b0',alpha=.15)
  if r['movement']=='reverse-command':ax.axvspan(10,15,color='#b0b0b0',alpha=.15)
 for ax in axes.flat:ax.grid(alpha=.2)
 m=r['metrics'];notes=f"Erreur finale hauteur {number(m.get('final_height_error'))} m ; excursion finale {number(m.get('tail_height_span'))} m ; assiette finale max {number(m.get('tail_tilt'))}° ; freinage {number(m.get('brake_seconds'))} s."
 notes+=' Critères échoués : '+(', '.join(r['failures']) or 'aucun')+'.'
 if r['reason']:notes+=' Arrêt : '+r['reason']
 fig.text(.05,.055,textwrap.fill(notes,155),fontsize=7,color=color)
 fig.text(.05,.025,'Gris : commande principale. Vert : fenêtre finale de stabilité. Modèle synthétique ; aucune qualification Minecraft.',fontsize=7)
 fig.subplots_adjust(left=.065,right=.975,bottom=.15,top=.87,hspace=.45,wspace=.32)
 pdf.savefig(fig);plt.close(fig)

def render_pdf(pdfpath,rr,work,protocols,seconds):
 signature=hashlib.sha256(json.dumps([{k:r[k] for k in ('fixture','controller','movement','status','failures','reason','metrics','trace_sha256')} for r in rr],sort_keys=True).encode()).hexdigest()
 token=dict(renderer=hashlib.sha256(inspect.getsource(plot_page).encode()).hexdigest(),format=1,inputs=signature)
 stamp=pdfpath.with_suffix('.json')
 if pdfpath.exists() and stamp.exists() and json.loads(stamp.read_text())==token:return False
 fixture,controller=rr[0]['fixture'],rr[0]['controller']
 with PdfPages(pdfpath,metadata={'Title':fixture+' / '+controller+' — campagne quad','Author':'MintCraftOS independent synthetic validation','CreationDate':None,'ModDate':None}) as pdf:
  plotted=0
  for r in rr:
   if r['trace']:plot_page(pdf,r,work/'results'/r['trace'],protocols[r['movement']],seconds);plotted+=1
  if not plotted:
   fig=plt.figure(figsize=(11.7,8.3));fig.text(.08,.88,fixture+' / '+controller+' — REFUSED',fontsize=18);fig.text(.08,.7,textwrap.fill(rr[0]['reason'],100),fontsize=11);fig.text(.08,.5,'Configuration refusée avant mouvement. Aucun des '+str(len(rr))+' mouvements ne constitue une réussite.',fontsize=11);pdf.savefig(fig);plt.close(fig)
 stamp.write_text(json.dumps(token))
 return True

def preplot(out,work,watch):
 manifest=json.loads((out/'campaign.json').read_text());plots=work/'plots';plots.mkdir(exist_ok=True)
 final_wait=0;seen={}
 while True:
  count=0
  for f in manifest['fixtures']:
   for controller in manifest['controllers']:
    folder=work/'results'/f['id']/controller;stamp=folder/'done.json'
    if not stamp.exists():continue
    count+=1
    stamp_hash=digest(stamp)
    if seen.get(str(folder))==stamp_hash:continue
    hashes=json.loads(stamp.read_text())['hashes']
    rr=[]
    for event in csv.DictReader((folder/'events.csv').open()):
     path=folder/(event['case']+'.csv');data=[{k:float(v) for k,v in r.items()} for r in csv.DictReader(path.open())] if path.exists() else []
     if path.exists():assert digest(path)==hashes[path.name]
     score=evaluate(data,event,event['case'],manifest['seconds'])
     rr.append(dict(fixture=f['id'],controller=controller,movement=event['case'],**score,trace=str(path.relative_to(work/'results')) if path.exists() else None,trace_sha256=digest(path) if path.exists() else None))
    if render_pdf(plots/(f['id']+'-'+controller+'.pdf'),rr,work,manifest['protocols'],manifest['seconds']):print('Preplotted',f['id'],controller,flush=True)
    seen[str(folder)]=stamp_hash
  if (out/'results.json').exists() or not watch:return
  if count==len(manifest['fixtures'])*len(manifest['controllers']):
   final_wait+=1
   if final_wait>20:raise RuntimeError('All workers complete but final campaign results are missing')
  time.sleep(5)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--work',type=Path,required=True);p.add_argument('--watch',action='store_true');a=p.parse_args()
 out=a.output.resolve();work=a.work.resolve()
 if a.watch:preplot(out,work,True)
 manifest=json.loads((out/'campaign.json').read_text());summary=json.loads((out/'results.json').read_text())
 rows=summary['results'];assert len(rows)==len(manifest['fixtures'])*len(manifest['controllers'])*len(manifest['cases'])
 plant_sha=digest(work/'snapshots/plant.lua');assert plant_sha==manifest['sources']['plant']
 for r in rows:
  if r['trace']:assert digest(work/'results'/r['trace'])==r['trace_sha256'],'Raw trace changed'
  if r['status']=='PASS':assert all(r['criteria'].values()) and len(r['criteria'])>=8,'Unsubstantiated PASS'
 plots=work/'plots';plots.mkdir(exist_ok=True);details=out/'details';details.mkdir(exist_ok=True)
 groups=collections.defaultdict(list)
 for r in rows:groups[(r['fixture'],r['controller'])].append(r)
 for index,((fixture,controller),rr) in enumerate(sorted(groups.items()),1):
  pdfpath=plots/(fixture+'-'+controller+'.pdf');lines=[f'# {fixture} / {controller}','',f"Protocole : {manifest['seconds']} s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.",'', '| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |','| --- | --- | ---: | ---: | ---: | ---: | --- |']
  render_pdf(pdfpath,rr,work,manifest['protocols'],manifest['seconds'])
  for r in rr:
   m=r['metrics'];lines.append('| '+r['movement']+' | '+r['status']+' | '+' | '.join(number(m.get(k)) for k in ('final_height_error','tail_height_span','tail_tilt','brake_seconds'))+' | '+(', '.join(r['failures']) or '—')+' |')
  if rr[0]['reason'] and all(r['status']=='REFUSED' for r in rr):lines+=['','Refus initial : '+rr[0]['reason']]
  lines+=['','Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/'+pdfpath.name+'` et `traces/'+fixture+'/'+controller+'/`.']
  (details/(fixture+'-'+controller+'.md')).write_text('\n'.join(lines)+'\n')
  print(f'Plots {index}/{len(groups)}: {fixture}/{controller}',flush=True)
 # Coverage map makes missing/unsupported architectures explicit.
 ordered=sorted(groups);cases=manifest['cases'];matrix=[]
 for key in ordered:matrix.append([{'PASS':0,'FAIL':1,'REFUSED':2}[next(r for r in groups[key] if r['movement']==case)['status']] for case in cases])
 fig,ax=plt.subplots(figsize=(15,max(9,len(ordered)*.22)));ax.imshow(matrix,aspect='auto',interpolation='nearest',cmap=ListedColormap(['#55ad6a','#d96565','#aaaaaa']),vmin=0,vmax=2)
 ax.set_xticks(range(len(cases)),cases,rotation=65,ha='right',fontsize=7);ax.set_yticks(range(len(ordered)),[f'{f}/{c}' for f,c in ordered],fontsize=6)
 ax.set_title('Campagne quad — vert PASS, rouge FAIL, gris REFUSED\nChaque cellule = tous les critères du mouvement ; modèle synthétique uniquement',fontsize=12);fig.tight_layout();fig.savefig(out/'coverage.png',dpi=170);plt.close(fig)
 failures=collections.Counter(k for r in rows if r['status']=='FAIL' for k in r['failures']);fig,ax=plt.subplots(figsize=(10,6));items=failures.most_common()[::-1];ax.barh([k for k,v in items],[v for k,v in items]);ax.set(xlabel='Nombre de mouvements en échec',title='Critères échoués — sans masquer les instabilités');fig.tight_layout();fig.savefig(out/'failures.png',dpi=160);plt.close(fig)
 # Archive is deliberately separate from the <1 MB flight distribution.
 archives=[]
 for controller in manifest['controllers']:
  archive=out/('campaign-traces-'+controller+'.zip')
  with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
   for fixture in manifest['fixtures']:
    folder=work/'results'/fixture['id']/controller
    for path in sorted(folder.rglob('*')):
     if path.is_file() and path.name not in ('bootstrap.lua','done.json'):z.write(path,'traces/'+path.relative_to(work/'results').as_posix())
   for path in sorted((work/'snapshots').glob('*')):z.write(path,'frozen-sources/'+path.name)
   for n in ('campaign.json','results.json','results.csv'):z.write(out/n,n)
   z.write(Path(__file__),'frozen-sources/report-sputnik-quad-campaign.py')
  archives.append(archive)
 for controller in manifest['controllers']:
  archive=out/('campaign-plots-'+controller+'.zip')
  with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
   for path in sorted(plots.glob('*-'+controller+'.pdf')):z.write(path,'plots/'+path.name)
  archives.append(archive)
 assert all(p.stat().st_size<95000000 for p in archives),'Split an archive before GitHub publication'
 total=summary['total'];counts=summary['counts'];accepted_pairs=[key for key,rr in groups.items() if any(r['status']!='REFUSED' for r in rr)];complete_pairs=[key for key,rr in groups.items() if all(r['status']=='PASS' for r in rr)]
 text=['# Campagne lourde quad — contrôleurs Sputnik '+manifest['distribution_version'],'',
 f"**{total} essais : {counts['PASS']} PASS, {counts['FAIL']} FAIL, {counts['REFUSED']} REFUSED.** Aucun essai dans Minecraft. Un refus n'est jamais compté comme une stabilisation réussie.",'',
 f"{len(manifest['fixtures'])} configurations × {len(cases)} mouvements × {len(manifest['controllers'])} contrôleurs ; {summary['simulated_seconds']/3600:.2f} heures simulées effectivement exécutées, {summary['solver_steps']:,} pas de mécanique et {sum(r['frames'] for r in rows):,} cycles complets de commande intégrés. Temps réel du banc : {summary['wall_seconds']/60:.1f} minutes avec quatre travailleurs maximum.",'',
 f"Configurations ayant réussi **tous** les mouvements : {len(complete_pairs)}/{len(accepted_pairs)} couples configuration/contrôleur acceptés. {len(groups)-len(accepted_pairs)} autres couples sont refusés avant activation. Ce nombre seul ne constitue pas une qualification Minecraft.",'',
 '![Matrice de couverture](coverage.png)','',
 '## Contrat de validation','',
 'L’assiette demandée pendant un déplacement peut être inclinée. Le suivi de cette assiette et le maintien vertical sont évalués pendant le mouvement ; le retour à une assiette horizontale et à une vitesse faible est évalué séparément en fin de parcours. Les courbes sont conservées même pour les échecs. Les cases grises sont des configurations refusées avant activation, pas des essais dynamiques réussis.','',
 'Les conditions exactes, empreintes et hypothèses figurent dans [campaign.json](campaign.json). Les résultats par critère sont dans [results.json](results.json), les mesures comparables dans [results.csv](results.csv). Les 20 Hz du contrôleur et 200 Hz du corps rigide sont des pas de simulation ; ils ne garantissent pas les performances du serveur.','',
 'Les termes « architecture » désignent ici la géométrie et la motorisation des quadricoptères. Les ballons, Venator et hélicoptères ne sont pas inclus dans cette campagne. Les contrôleurs effectivement exécutés sont listés dans campaign.json. Les refus de configuration sont conservés ; la comparaison avec une version antérieure est un rapport distinct.','',
 '## Seuils communs par phase','']
 for k,v in manifest['criteria'].items():text.append('- **'+k+'** : '+v)
 text+=['','## Mouvements et protocoles','']
 for name in cases:text.append('- **'+name+'** : '+manifest['protocols'][name])
 text+=['','## Résultats par configuration','', '| Configuration / contrôleur | PASS | FAIL | REFUSED | Rapport détaillé |','| --- | ---: | ---: | ---: | --- |']
 for (f,c),rr in sorted(groups.items()):
  count=collections.Counter(r['status'] for r in rr);text.append(f"| {f} / {c} | {count['PASS']} | {count['FAIL']} | {count['REFUSED']} | [24 mouvements](details/{f}-{c}.md) |")
 text+=['','## Principales limites révélées','', '![Critères échoués](failures.png)','',
 'La réussite du maintien seul ne certifie ni une diagonale, ni un virage, ni une montée avec déplacement. Les échecs et l’absence de réserve de poussée restent des travaux ouverts : les contrôleurs testés ont été figés pendant la campagne, sans ajustement des seuils après lecture des résultats.','',
 'La mécanique n’inclut ni collisions, ni réseaux de stress, ni contacts, ni solveur de joints Minecraft fidèle, ni couples gyroscopiques des hélices. Le câble est un modèle ponctuel unilatéral avec correction de dérive numérique. Les masses et inerties sont des scénarios synthétiques déclarés, pas un scan du vaisseau. Aucun lacet du nez n’est exigé de quatre hélices verticales fixes.','',
 'Les archives de traces et de courbes sont séparées de la distribution de vol. Chaque mouvement exécuté a une page de courbes dans le PDF de son couple configuration/contrôleur. Les sources gelées accompagnent les traces. La distribution de vol reste inchangée.','',
 '## Reproduire','',
 'Installer `numpy`, `matplotlib` et `pypdf` pour le rendu et la vérification. Les versions utilisées sont conservées dans `environment.json` lorsque ce fichier accompagne la campagne.','',
 'Depuis ce dépôt, avec le JDK 21 et le JAR Cosmonautics 26.08.307 dont l’empreinte est contrôlée :','',
 '```sh','python3 tools/test-quad-campaign-contract.py','python3 tools/run-sputnik-quad-campaign.py --cosmonautics-jar /chemin/cosmonautics.jar --java-home /chemin/jdk-21 --output /tmp/quad-report --work /tmp/quad-work --controllers '+','.join(manifest['controllers'])+' --tilt '+str(manifest.get('tilt_degrees',20))+' --jobs 4','python3 tools/report-sputnik-quad-campaign.py --output /tmp/quad-report --work /tmp/quad-work','```','',
 'Utiliser des dossiers neufs. `--resume` exige exactement les mêmes sources, paramètres, critères et empreintes ; les traces terminées sont contrôlées avant réutilisation. Aucun téléchargement de JAR n’est effectué par le banc.']
 links=[]
 for path,label in [('FINDINGS.md','Conclusions et corrections prioritaires'),('METHOD.md','Méthode détaillée'),('convergence/README.md','Sensibilité 200/400 Hz')]:
  if (out/path).exists():links.append('['+label+']('+path+')')
 if links:text[6:6]=[' · '.join(links),'']
 text+=['','## Archives téléchargeables','']
 for archive in archives:text.append('- ['+archive.name+']('+archive.name+') : '+f'{archive.stat().st_size/1000000:.1f}'+' Mo')
 (out/'README.md').write_text('\n'.join(text)+'\n')
 artifact_record=dict(schema=1,archives={p.name:dict(sha256=digest(p),bytes=p.stat().st_size) for p in archives},renderer_sha256=digest(Path(__file__)),campaign_sha256=digest(out/'campaign.json'),results_sha256=digest(out/'results.json'),trace_count=sum(r['trace'] is not None for r in rows),executed_simulated_seconds=summary['simulated_seconds'])
 (out/'artifacts.json').write_text(json.dumps(artifact_record,indent=2)+'\n')
 (out/'SHA256SUMS').write_text(''.join(digest(p)+'  '+p.relative_to(out).as_posix()+'\n' for p in sorted(out.rglob('*')) if p.is_file() and p.name!='SHA256SUMS'))
 print('Report published:',out,'archive bytes:',sum(p.stat().st_size for p in archives),flush=True)
if __name__=='__main__':main()
