#!/usr/bin/env python3
"""Publish and verify the bounded-envelope regression without hiding failures."""
import argparse,collections,hashlib,importlib.util,json,zipfile
from pathlib import Path
from quad_campaign_contract import MOVEMENTS
spec=importlib.util.spec_from_file_location('plots',Path(__file__).with_name('report-sputnik-quad-campaign.py'));plots=importlib.util.module_from_spec(spec);spec.loader.exec_module(plots)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output;work=a.work
 rows=json.loads((out/'results.json').read_text())['results'];assert len(rows)==96
 manifest=json.loads((out/'manifest.json').read_text());groups=collections.defaultdict(list)
 for r in rows:
  groups[r['fixture'],r['controller']].append(r)
  if r['trace']:assert sha(work/'results'/r['trace'])==r['trace_sha256']
 parity=[]
 for r in rows:
  if r['controller']=='fixed':
   old=next(v for v in rows if v['fixture']==r['fixture'] and v['movement']==r['movement'] and v['controller']=='baseline')
   assert old['trace_sha256']==r['trace_sha256'];parity.append([r['fixture'],r['movement']])
 assert len(parity)==32
 figures=out/'plots';figures.mkdir(exist_ok=True)
 for (fixture,controller),rr in groups.items():
  plots.render_pdf(figures/(fixture+'-'+controller+'.pdf'),rr,work,MOVEMENTS,manifest['seconds']);print('Report',fixture,controller,flush=True)
 archive=out/'observations-and-sources.zip'
 with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  for folder in ('snapshots','results'):
   for file in sorted((work/folder).rglob('*')):
    if file.is_file():z.write(file,file.relative_to(work))
  z.write(out/'manifest.json','manifest.json');z.write(out/'results.json','results.json')
 with zipfile.ZipFile(archive) as z:assert z.testzip() is None
 lines=['# Régression native 0.4.0 — enveloppe de stabilité','','96 scénarios : 4 montages × 8 mouvements × 3 variantes. 60 s par scénario, contrôle 20 Hz, physique 200 Hz. Modèle synthétique 6DOF indépendant ; aucune qualification Minecraft.','','`baseline` = 0.3.5 ; `fixed` = 0.4.0 avec facteur 1 ; `limited` = 0.4.0 avec facteur imposé 0,5. Ce banc compare les effets de la réduction d’inclinaison ; il ne simule pas la politique adaptative complète. Celle-ci est vérifiée séparément dans les tests LuaJ.','','Les 32 traces complètes à facteur 1 sont identiques octet par octet à celles de la 0.3.5. La réduction ne garantit pas la stabilité : les échecs restent visibles ci-dessous.','','| Montage | Variante | PASS | FAIL | REFUSED |','| --- | --- | ---: | ---: | ---: |']
 for (f,c),rr in sorted(groups.items()):
  count=collections.Counter(r['status'] for r in rr);lines.append(f'| {f} | {c} | {count["PASS"]} | {count["FAIL"]} | {count["REFUSED"]} |')
 lines+=['','## Chaque mouvement','','| Montage | Variante | Mouvement | État | Critères échoués |','| --- | --- | --- | --- | --- |']
 for r in rows:lines.append('| '+ ' | '.join([r['fixture'],r['controller'],r['movement'],r['status'],', '.join(r['failures']) or '—'])+' |')
 lines+=['','Les PDF dans `plots/` montrent chaque trajectoire, altitude, assiette, vitesse et sortie Link. Les excursions et mesures détaillées restent dans `results.json`. L’archive contient les traces intégrales, les sources figées, la plante et les paramètres. La politique peut réduire la demande horizontale et demander une pause ; elle ne remplace pas un modèle physique correct et ne coupe pas mécaniquement les moteurs.']
 (out/'README.md').write_text('\n'.join(lines)+'\n');(out/'parity.json').write_text(json.dumps(dict(schema=1,identical_complete_traces=parity),indent=2)+'\n')
 files=[f for f in sorted(out.rglob('*')) if f.is_file() and f.name!='SHA256SUMS'];(out/'SHA256SUMS').write_text(''.join(sha(f)+'  '+str(f.relative_to(out))+'\n' for f in files))
if __name__=='__main__':main()
