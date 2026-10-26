# Livraison quad Sputnik 0.3.4 — charge décentrée

TXT complet : `../../dist/mintcraft-quad-fpv.clipboard.txt`. Conserver source 256 RPM et transmissions 0–15. Aucun nouveau champ de centre de masse ni modification mécanique. Exporter les groupes MCV1, retirer l’ancien contrôleur, importer le nouveau graphe et réimporter les réglages. Au sol, effectuer le passage physique OFF requis avant activation. Un seul contrôleur possède les fréquences moteur ; la fermeture de l’éditeur ne garantit pas un arrêt serveur.

L’estimation passive du déséquilibre corrige les bras de levier effectifs utilisés par l’allocation. Elle utilise les accélérations angulaires mesurées, normalise par la poussée estimée et transporte le résidu de modulation lors des changements de masse/inertie. Aucun balayage, impulsion de calibration ou changement de cible verticale. Le solveur cherche une répartition bornée dans toute la famille de solutions des quatre moteurs. Le modèle standard et les autres architectures restent inchangés.

72 scénarios natifs LuaJ comparent les deux versions : 12 montages × maintien, avance/freinage et avance-gauche. Les succès COM passent de 6/36 à 15/36 ; les anciens critères complets de 2/36 à 14/36. Dans le cas d’ajout puis retrait d’une charge éloignée, le pic d’erreur verticale au maintien passe de 54,25 m à 0,62 m. La consigne reste inchangée. Les critères COM vérifient notamment 20 observations fraîches successives après chaque épisode ; ils sont distincts des anciens critères complets, tous conservés.

Les délais importants, certains changements de côté, les hélices hétérogènes et les manœuvres conservent des échecs. Un centre extérieur au support des hélices est physiquement irréalisable. L’estimation ne mesure pas le centre réel et n’identifie pas la cause d’un défaut. Aucune garantie de maintien universel, aucun essai Minecraft ou de vrais joints n’est revendiqué.

Les preuves lourdes restent hors du ZIP de vol : [charges et limites](../quad-com-0.3.4/README.md), [campagne générale](../quad-campaign-0.3.4/README.md). Sources, tests et configuration exportable restent dans l’archive courante. Le plan A–F n’est pas intégralement qualifié.

Campagne générale inchangée : **386 PASS / 166 FAIL / 24 REFUSED**, contre 394/158/24 en 0.3.3. Les [régressions détaillées](../quad-campaign-0.3.4/FINDINGS.md) restent publiées.

Vérification des sources et imports : vrai LuaJ Cosmonautics 26.08.307, équivalence lisible/compact et modèle vertical sur 100 poses, équilibre intérieur au support et refus extérieur, couples faibles signés conservés, 32 TXT SNBT/NBT/CODEC. Le contrôleur quad occupe 59 739 octets UTF modifié. Le contrôle du pas de mécanique 200/400 Hz conserve les quatre classifications de référence. [Journal natif](../quad-com-0.3.4/native-checks.log). Les preuves de charge sont vérifiées indépendamment pour chaque tenseur réel et chaque conversion origine/centre.
