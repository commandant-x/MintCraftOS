#!/usr/bin/env python3
"""Aggregate completed, hash-checked universal runs without hiding failed scenarios."""
import csv, hashlib, io, json
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
base=ROOT/'platforms/sputnik/reports/universal-0.2.0'
dist=ROOT/'platforms/sputnik/dist'
manifest=json.loads((dist/'manifest.json').read_text())
digest=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
expected={'controller_sha256':digest(dist/'mintcraft-autopilot-control.lua'),
 'plant_sha256':digest(ROOT/'tools/sputnik-universal-twin.lua'),
 'defaults_sha256':digest(ROOT/'platforms/sputnik/src/vehicle_model.lua')}
validation=json.loads((base/'validation.json').read_text())
assert validation['exit_code']==0 and validation['controller_sha256']==expected['controller_sha256']
assert validation['validation_log_sha256']==digest(base/'validation.log'),'Validation log changed'
assert validation['host_sha256']==manifest['hostJarSha256'] and validation['version']==manifest['version']
assert validation['native_sources']==manifest['nativeSources'],'Native fixtures belong to other sources'
assert validation['clipboard_sha256']==digest(dist/'mintcraft-autopilot.clipboard.txt'),'Validated graph changed'
runs={}
for name in [f'profile-{i}' for i in range(1,6)]+['low-inertia-delay','offset-weak-rotor','mass-damage']:
 folder=base/name;data=json.loads((folder/'summary.json').read_text())
 assert all(data[k]==v for k,v in expected.items()),'Outdated source snapshot: '+name
 assert data['csv_sha256']==digest(folder/'summary.csv'),'Torn/mismatched CSV: '+name
 assert data['host_sha256']==manifest['hostJarSha256'] and data['version']==manifest['version']
 rows=list(csv.DictReader((folder/'summary.csv').open()))
 assert rows==data['scenarios'] and len(rows)==data['total']
 runs[name]=data
reference=[r for name,d in runs.items() if name.startswith('profile-') for r in d['scenarios']]
stress=[r for name,d in runs.items() if name in ('low-inertia-delay','offset-weak-rotor') for r in d['scenarios']]
damage=runs['mass-damage']['scenarios']
report=dict(version=manifest['version'],tested_in_minecraft=False,qualified=False,**expected,
 reference_passed=sum(r['status']=='PASS' for r in reference),reference_total=len(reference),
 stress_passed=sum(r['status']=='PASS' for r in stress),stress_total=len(stress),
 damage_passed=sum(r['status']=='PASS' for r in damage),damage_total=len(damage),
 runs={name:{'passed':d['passed'],'total':d['total'],'fixture':d['fixture']} for name,d in runs.items()},
 failures=[dict(run=name,**r) for name,d in runs.items() for r in d['scenarios'] if r['status']!='PASS'])
(base/'summary.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
buffer=io.StringIO();writer=csv.DictWriter(buffer,fieldnames=['run']+list(reference[0]),lineterminator='\n');writer.writeheader()
for name,d in runs.items():
 for r in d['scenarios']:writer.writerow(dict(run=name,**r))
(base/'summary.csv').write_text(buffer.getvalue())
text=['# Autopilote Sputnik '+manifest['version']+' — résultats','',
 f"Référence : **{report['reference_passed']}/{report['reference_total']}**. Stress : **{report['stress_passed']}/{report['stress_total']}**. Changement de masse avec réponse dégradée : **{report['damage_passed']}/{report['damage_total']}**.",'',
 '**Le code Lua livré est exécuté dans LuaJ de Cosmonautics. La mécanique est une plante synthétique indépendante, pas une copie mesurée du véhicule Minecraft.**','',
 'Les sources, le programme mécanique et les CSV sont vérifiés par empreinte avant agrégation. Une exécution travaille dans un dossier privé et verrouille sa destination. Les résultats incomplets ou provenant d\'un autre contrôleur sont refusés.','',
 '| Série | Réussites | Domaine |','| --- | ---: | --- |']
labels={'profile-1':'Quad à petites hélices','profile-2':'Ballon avec gouverne dépendante du mouvement','profile-3':'Venator, 4 sustentations et 2 banques de 2 moteurs','profile-4':'Hélicoptère, sustentation centrale + propulsion + couple de lacet déclaré','profile-5':'Quad modulaire asymétrique, 8/12/16/20 voiles','low-inertia-delay':'Inerties ×0,25, retard 2 ticks, bruit position 0,01 m','offset-weak-rotor':'COM réel décalé de 0,5 m et rotor 1 à 70 % du modèle dès le départ','mass-damage':'À 6 s : masse −12,5 %, COM décalé de 0,5 m et rotor 1 à 70 %, depuis un maintien initial connu'}
for name,d in runs.items():text.append(f"| [{name}]({name}/README.md) | {d['passed']}/{d['total']} | {labels[name]} |")
text+=['','Les dix cas de référence sont maintien, changement de hauteur, avance, recul, virage, changement de masse, calibration, mission courte, mission rectiligne et déplacement maintenu 20 s. La mission rectiligne part de la position réellement atteinte après calibration ; elle ne remplace pas le cas court plus contraignant.','',
 'Critères : absence de défaut, erreur finale de hauteur < 1 m, inclinaison maximale < 25°, vitesse finale < 0,3 m/s et RMS de vitesse sur les 10 dernières secondes < 0,35 m/s. Les déplacements doivent réellement parcourir > 0,2 m ; le lacet doit être observé si disponible. La calibration et la mission doivent se terminer pour réussir leur cas. Pour le déplacement prolongé du quad : inclinaison moyenne > 6° et dispersion < 1,5°. Les excursions transitoires sont publiées séparément ; une erreur maximale inclut les changements demandés de consigne.','',
 'L\'arrivée est un maintien, pas un atterrissage. Le ballon à gouverne n\'est pas qualifié pour les routes serrées qui échouent. Un maintien réussi ne qualifie pas tous les virages. Les inerties, le coefficient de gouverne et les réponses linéaires sont des hypothèses explicites du banc. Les valeurs zéro d\'un cas REFUSED indiquent que la plante n\'a pas été démarrée, pas une excursion mesurée nulle.','',
 'Les tests du graphe natif couvrent séparément OFF physique, absence de réarmement, cible modifiée sans réinitialisation, doublons, montage figé, héritage des sorties, coupure, mise en repli continue et sérialisation SNBT/NBT réelle. Voir `validation.log`.','',
 '## Échecs conservés','']
for r in report['failures']:text.append(f"- {r['run']} / {r['scenario']} : {r['status']} ; erreur finale hauteur {float(r['altitude_error']):.3f} m, inclinaison maximale {float(r['max_tilt']):.2f}°, vitesse finale {float(r['final_speed']):.3f} m/s.")
text+=['','## Reproduire','',
 '```sh','python3 tools/build-sputnik.py',
 'python3 tools/test-sputnik-universal.py --cosmonautics-jar /chemin/cosmonautics-26.08.307.jar --java-home /chemin/jdk21 --profiles 1 --output /tmp/quad-test',
 'python3 tools/report-sputnik-universal.py','```','',
 'Exécuter les cinq profils et les deux jeux de stress et le changement de masse avec réponse dégradée dans leurs dossiers respectifs avant agrégation. Les paramètres exacts sont dans chaque `summary.json`. Les JAR audités ne sont pas redistribués.']
(base/'README.md').write_text('\n'.join(text)+'\n')
print('Verified universal report:',report['reference_passed'],'/',report['reference_total'],'reference;',report['stress_passed'],'/',report['stress_total'],'stress')
