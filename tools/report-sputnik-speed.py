#!/usr/bin/env python3
"""Audit native speed windows against archived CSV; publish bounded measurements."""
import argparse,csv,gzip,hashlib,json,math,shutil
from pathlib import Path

def digest(data):return hashlib.sha256(data).hexdigest()
def audit(rows,stage,direction,heading):
 a=[rows[t] for t in range(stage['window_first_tick'],stage['window_last_tick']+1)]
 vertical=direction['vertical'];n=60 if vertical else 100
 assert len(a)==n==stage['window_samples'],'window length'
 angle=math.radians(heading+direction['angle']);values=[];tilts=[]
 for i,r in enumerate(a):
  assert all(math.isfinite(v) for v in r.values()),'nonfinite'
  assert r['active']==1 and r['protection']==0 and r['staff_locked']==0,'assisted or inactive'
  assert r['observed_mass']>0 and abs(r['observed_mass']-a[0]['observed_mass'])<=a[0]['observed_mass']*.0001,'mass'
  if i:assert r['universe_tick']==a[i-1]['universe_tick']+1,'stale tick'
  tilt=math.degrees(math.acos(max(-1,min(1,math.cos(math.radians(r['pitch']))*math.cos(math.radians(r['roll']))))))
  tilts.append(tilt)
  speed=r['vy']*vertical if vertical else r['vx']*math.sin(angle)+r['vz']*math.cos(angle)
  cross=math.hypot(r['vx'],r['vz']) if vertical else abs(r['vx']*math.cos(angle)-r['vz']*math.sin(angle))
  assert cross<=(.3 if vertical else .5)+1e-8,'cross drift'
  assert tilt<=(5 if vertical else 25)+1e-8,'tilt'
  assert abs(r['target_y']-r['y'])<=(max(2,stage['requested_m_s']*3) if vertical else 1)+1e-8,'altitude'
  if vertical:assert abs(speed-stage['requested_m_s'])<=max(.3,stage['requested_m_s']*.15)+1e-8,'vertical tracking'
  else:assert abs(r['vy'])<=.15+1e-8,'vertical drift'
  values.append(speed)
 mean=sum(values)/n
 assert abs(mean-stage['window_mean_m_s'])<1e-7,'reported mean'
 assert mean>.15 and max(values)-min(values)<=max(.25,.05*mean)+1e-8,'speed variation'
 assert max(tilts)-min(tilts)<=3+1e-8,'tilt variation'
 assert abs(sum(values[n//2:])/(n//2)-sum(values[:n//2])/(n//2))<=.1+1e-8,'ongoing acceleration'
 assert a[0]['universe_tick']==stage['window_first_universe_tick'] and a[-1]['universe_tick']==stage['window_last_universe_tick'],'window boundaries'
 if stage.get('braking_verified'):
  start=stage['last_tick'];first=start+round(stage['braking_duration_s']*20);end=first+99
  for t in range(first,end+1):
   r=rows[t];assert math.sqrt(r['vx']**2+r['vy']**2+r['vz']**2)<=.2+1e-8,'brake speed'
   assert abs(r['y']-r['target_y'])<=1+1e-8,'brake altitude'
   tilt=math.degrees(math.acos(max(-1,min(1,math.cos(math.radians(r['pitch']))*math.cos(math.radians(r['roll']))))))
   assert tilt<=5+1e-8,'brake tilt'
   assert r['active']==1 and r['protection']==0 and r['staff_locked']==0,'brake assistance'
   if t>first:assert r['universe_tick']==rows[t-1]['universe_tick']+1,'brake freshness'
  base=rows[start];brake=[rows[t] for t in range(start+1,end+1)]
  distance=max(math.hypot(r['x']-base['x'],r['z']-base['z']) for r in brake)
  loss=max(0,base['y']-min(r['y'] for r in brake))
  assert abs(distance-stage['braking_distance_m'])<1e-6,'brake distance'
  assert abs(loss-stage['braking_height_loss_m'])<1e-6,'brake height loss'
 return mean

def main():
 p=argparse.ArgumentParser();p.add_argument('campaign',type=Path);p.add_argument('output',type=Path);args=p.parse_args();args.output.mkdir(parents=True,exist_ok=True)
 summaries=[];audited=0
 for path in sorted(args.campaign.rglob('speed-results.json')):
  fixture=path.parent;run=fixture.parent;case=run.name;target=args.output/case;target.mkdir(exist_ok=True)
  result=json.loads(path.read_text());contract=json.loads((fixture/'speed-contract.json').read_text());exitdata=json.loads((run/'exit.json').read_text());assert result['complete'] and exitdata['sequence_completed'] and not exitdata['fixture_error']
  rows={int(r['tick']):{k:float(v) for k,v in r.items()} for r in csv.DictReader((fixture/'flight.csv').open())};heading=rows[320]['yaw'];directions={d['name']:d for d in contract['directions']}
  for s in result['stages']:
   if s['status']=='CRUISE_STABLE':audit(rows,s,directions[s['direction']],heading);audited+=1
  for r in result['directions']:
   if 'confirmed_speed_m_s' in r:
    matches=[s for s in result['stages'] if s.get('braking_verified') and s['direction']==r['direction'] and abs(s['window_mean_m_s']-r['confirmed_speed_m_s'])<1e-8]
    assert matches,'unpaired braking result'
   summaries.append({'architecture':case,**{k:v for k,v in r.items() if k!='highest_cruise_stable_stage'}})
  for f in ['speed-results.json','speed-contract.json','events.tsv','geometry.txt','hardware.tsv','test-contract.json']:
   if (fixture/f).exists():shutil.copy2(fixture/f,target/f)
  for f in ['run.json','exit.json','mintcraft-generic-controller.lua','mintcraft-generic-setup.lua','mintcraft-operations.lua','template.clipboard.txt']:
   shutil.copy2(run/f,target/f)
  raw=(fixture/'flight.csv').read_bytes();compressed=gzip.compress(raw,compresslevel=9,mtime=0);(target/'flight.csv.gz').write_bytes(compressed)
  (target/'trace-integrity.json').write_text(json.dumps({'csv_sha256':digest(raw),'gzip_sha256':digest(compressed),'rows':len(rows)},indent=2)+'\n')
 assert len(summaries)==46,'missing architecture or direction'
 doc={'complete':True,'globallyQualified':False,'directions':summaries,'auditedStableStages':audited,'confirmedDirections':sum('confirmed_speed_m_s' in r for r in summaries),'auditScope':'CSV independently checks cruise speed, freshness, unlock, altitude, cross drift, tilt, and confirmed stopping speed/distance/height loss. ACK and adaptation scale are checked by the Java observer, absent from CSV. Native resetting occurs only outside qualified windows.'}
 (args.output/'summary.json').write_text(json.dumps(doc,ensure_ascii=False,indent=2)+'\n')
 lines=['# Vitesses mesurées dans Minecraft — Sputnik 0.4.3','','46 directions sur six constructions natives. Les valeurs sont les meilleures vitesses mesurées avec croisière stable **et freinage validé** dans cette campagne. Un tiret signifie aucune vitesse prouvée par ce protocole, pas une impossibilité de voler.','','| Construction | Direction | m/s | km/h | Freinage (s) | Excursion horizontale (blocs) | Perte altitude au freinage (blocs) |','|---|---|---:|---:|---:|---:|---:|']
 for r in summaries:
  values=[f"{r[k]:.2f}" if k in r else '—' for k in ['confirmed_speed_m_s','confirmed_speed_km_h','braking_duration_s','braking_distance_m','braking_height_loss_m']]
  lines.append('| '+ ' | '.join([r['architecture'],r['direction'],*values])+' |')
 lines+=['','## Portée et limites','','Minecraft 1.21.1, NeoForge 21.1.264, mods du pack VENATOR fourni. Serveurs sans interface graphique : physique et blocs réels, commandes publiques Sputnik et fréquences Link. Aucun test de touches physiques ni de client multijoueur. Les véhicules sont les six constructions du banc 0.4.2 ; hélicoptère, avion et V22 ne sont pas inclus.','','Inclinaison configurée 20°, commandes verticales 1 à 5 m/s ; recherche horizontale 2 à 64 m/s, puis jusqu’à trois affinages. Ces résultats bornent le comportement de ce pilote et de ces montages, et ne constituent pas une vitesse maximale physique absolue. Une première tentative à 2 m/s qui échoue ne prouve rien sur les vitesses inférieures. Un échec de freinage ne fournit aucune vitesse confirmée. Le quad avec propulsion dédiée est testé à commande manuelle pleine ; gauche/droite commandent son lacet, pas une translation.','','Croisière : 100 ticks frais horizontaux (5 s), 60 verticaux (3 s), sans verrou ni protection ni réduction adaptative. Dérive latérale ≤0,5 m/s horizontale, ≤0,3 verticale ; variation de vitesse ≤max(0,25 m/s, 5 %), variation entre demi-fenêtres ≤0,1 m/s. Altitude horizontale ±1 bloc, vitesse verticale ≤0,15 m/s. Arrêt : vitesse totale ≤0,2 m/s et altitude ±1 bloc pendant 100 ticks. La durée exclut ces cinq secondes de confirmation. L’excursion horizontale et la perte d’altitude incluent toute la fenêtre de freinage ; pour une montée, la perte peut inclure un dépassement suivi d’un retour.','','Les directions sont des vecteurs du monde relatifs au cap initial, sans garantie que le nez conserve ce cap. Ne pas interpréter les asymétries comme des limites aérodynamiques universelles. Les pics transitoires ne sont pas les vitesses retenues.','','Le correctif 0.4.3 conserve le contrôle horizontal lors des commandes exclusivement verticales. Les sources exactes testées, graphes de départ, géométries, commandes et traces compressées sont joints par construction. Les mondes téléchargeables restent en 0.4.2 ; importer le nouveau contrôleur séparément.','','Audit indépendant : '+str(audited)+' fenêtres stables relues dans les CSV ; '+str(doc['confirmedDirections'])+'/46 directions avec arrêt confirmé. ACK et facteur adaptatif sont vérifiés dans le Java du banc, mais ne sont pas présents dans les CSV. Les verrouillages et téléportations de réinitialisation sont exclus des fenêtres.','','Les fichiers `speed-results.json` conservent aussi les paliers rejetés, les pics et les motifs d’échec. `summary.json` omet volontairement la vitesse si elle n’est pas prouvée.']
 (args.output/'README.md').write_text('\n'.join(lines)+'\n');print(json.dumps({k:v for k,v in doc.items() if k!='directions'},indent=2))
if __name__=='__main__':main()
