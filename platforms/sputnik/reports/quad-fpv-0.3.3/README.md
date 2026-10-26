# Livraison quad Sputnik 0.3.3 — matériel inchangé

TXT complet : `../../dist/mintcraft-quad-fpv.clipboard.txt`. Conserver la vraie source à 256 RPM et les transmissions 0–15. Aucun nouveau champ ni changement mécanique demandé. Exporter les groupes MCV1, retirer l'ancien graphe avant de réutiliser ses fréquences, importer le nouveau TXT et réimporter les réglages. Au sol, effectuer le passage physique OFF requis avant activation. Un seul contrôleur doit posséder les fréquences moteur.

Le raccourci qui imposait un même signal aux quatre moteurs pour de faibles écarts est supprimé. Il effaçait également le résidu de couple. Un seul quantificateur conserve maintenant les faibles corrections différentielles. Une comparaison des sources confirme que les gains, filtres, modèles, observateurs et géométrie sont inchangés.

Régression native LuaJ à 256 RPM, référence 32 kg/12 voiles/départ 3° : maintien durable 33,70 → 0,95 s ; freinage 46,60 → 5,95 s ; perturbation diagonale 51,10 → 4,20 s. La référence passe les 24 mouvements. Le test des très faibles couples signés échoue sur l'ancien contrôleur et réussit sur le correctif.

Sur la campagne complète : 394 PASS / 158 FAIL / 24 REFUSED, avec 9 améliorations et 8 régressions des anciens critères. Sur les 552 traces, 346 retrouvent une stabilité durable en au plus 8 s contre 251 auparavant. Le correctif ne valide pas tous les montages ; forts retards, poussée surdimensionnée et faibles inerties conservent des échecs. Une récupération inversée peut encore perdre environ 11 m. Aucun vol Minecraft n'est revendiqué.

Les preuves lourdes restent séparées du ZIP de vol : [campagne](../quad-campaign-0.3.3/README.md), [limites/régressions](../quad-campaign-0.3.3/FINDINGS.md), [régime fixe et départs inclinés](../quad-pwm-0.3.3/README.md). Les sources, tests, interface et configuration exportable sont livrés ; le plan A–F n'est pas intégralement qualifié.
