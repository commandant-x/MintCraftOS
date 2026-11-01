# Flotte Sputnik 0.4.1 — essais Minecraft réels

Trois familles, cinq géométries construites et six configurations essayées dans Minecraft. **Aucun profil n’est globalement qualifié.** Le Lua générique de production reste inchangé ; cette livraison ajoute le banc, les constructions, les mesures et les imports expérimentaux.

| Configuration | Masse native | Résultat |
|---|---:|---|
| Tricoptère Y | 111,5 kg | 5/9 : maintien, montée, descente, avance et choc réussis ; recul et déplacements latéraux ne se stabilisent pas dans la fenêtre prescrite. |
| Quad, propulsion arrière déportée | 156,25 kg | Maintien et montée échouent ; descente interrompue, suite non exécutée. |
| Quad équilibré, commande latérale | 134,75 kg | 5/9 complets ; Q/D/W+Q valident seulement le maintien final, sans déplacement latéral disponible ; choc échoué. |
| Quad équilibré, virage différentiel | 134,75 kg | 7/9 : maintien, montée, descente, avance, recul, virages Q et D réussis ; diagonale et choc échouent. |
| Ballon avec propulsion | 305,75 kg | Prévol refusé : « Equilibre sustentation invalide ». Aucun vol exécuté. |
| Ballon vertical symétrique | 261,25 kg | Séquence complète, mais 0/9 satisfont le maintien final strict. Les demandes horizontales ne sont pas disponibles sur ce montage ; leur maintien vertical échoue également. |

[Vue d’ensemble PNG](overview.png) · [PDF](overview.pdf) · [Résultats détaillés](results.json) · [Captures Minecraft originales](captures/index.json)

Chaque sous-dossier contient les mesures CSV, événements, géométrie, matériel observé, résultats et courbes des phases exécutées. Les révisions exactes du constructeur Java sont archivées dans `fixtures/` et référencées par chaque cas. Les captures proviennent du framebuffer Minecraft, sans retouche ; leurs horodatages ne donnent pas un tick serveur exact. Cinq captures ont été conservées, aucune pour le ballon avec propulsion. Le rendu logiciel peut montrer du terrain partiellement chargé ; les images ne prouvent pas la stabilité.

## TXT complets à importer

- [Tricoptère Y](tri-y.clipboard.txt)
- [Quad avec deux banques de propulsion, virage différentiel](quad-banks.clipboard.txt)
- [Ballon vertical](balloon-lift.clipboard.txt)

**Imports expérimentaux pour les nouveaux véhicules du banc, pas pour remplacer directement le montage de votre ancien quad.** Chaque TXT contient sept nœuds et 34 connexions, des UUID propres et aucun émetteur automatique du banc. Les valeurs d’entrée/sortie en cache sont effacées. Importer désarmé, maintenir physiquement OFF puis effectuer un nouveau prévol. Une transmission peut donner plein régime à 0 et s’arrêter à 15. Ne pas importer pendant un vol ou laisser deux pilotes sur les mêmes fréquences. Les limites du tableau s’appliquent aussi à ces TXT.

## Protocole et lecture des résultats

Minecraft 1.21.1, NeoForge 21.1.264, Create 6.0.10, Aeronautics/Simulated 1.3.2, Sable 2.0.6, Cosmonautics 26.08.307. Chaque configuration démarre dans une nouvelle copie du monde VENATOR et une nouvelle JVM locale. Construction par blocs réels, assemblage Sable, roulements, Links et physique natifs ; calcul Lua serveur. Le monde original reste intact et n’est pas redistribué. Le spectateur ne touche pas le véhicule. Le client graphique est arrêté après les captures initiales pour libérer du CPU ; le serveur continue.

Avant armement, un émetteur de test temporaire vérifie chaque arbre : signal 10, régime attendu 80 RPM pour une source 256 RPM, direction et poussée positive. Il est supprimé avant armement. Les nouvelles révisions maintiennent la zone chargée par un ticket serveur. Déverrouillage au tick 320 après passage physique OFF/ON. Le ballon vertical exige également 20 observations fraîches de force de sustentation à ±5 % du poids avant déverrouillage : ce contrôle verrouillé ne prouve pas un stationnaire en vol libre.

Phases successives : maintien, montée, descente, W, S, Q, D, W+Q, puis impulsion native de vitesse latérale +5 m/s. Touches maintenues 60 ticks ; phases de 400 ticks, choc observé 800 ticks. **Il s’agit d’un essai enchaîné à cadence fixe, pas d’une calibration ni de neuf essais indépendants.** L’état d’entrée de chaque phase est publié. Un choc après une diagonale échouée ne qualifie pas isolément la résistance au choc.

PASS exige le mouvement demandé lorsqu’il est disponible et, sur les 200 dernières observations fraîches, erreur d’altitude ≤1 m, vitesse verticale ≤0,1 m/s, vitesse horizontale ≤0,2 m/s, inclinaison ≤5° et pilote actif. H* valide seulement le maintien final lorsque la composante demandée est indisponible. Les excursions transitoires sont publiées séparément : le tricoptère dépasse notamment 2,2 m en montée/descente malgré son retour final conforme. « HOLDING » est le mode demandé, pas une mesure de stabilité. Les commandes sont injectées sur les Links réels ; la frappe physique au clavier et l’orientation du siège ne sont pas validées par ce banc.

## Constats et limites

- Le quad déporté place son centre de masse trop près d’une rangée de sustentation ; saturation à 256 RPM et dérive sont observées avant l’arrêt. La récupération de fin rencontre « Enable lever missing » après sortie de la zone chargée : défaut du banc, pas preuve de casse physique. Les révisions suivantes ajoutent un ticket de chargement.
- Seize blocs de voile sont posés par rotor. Les roulements assemblent réellement huit voiles par rotor vertical et seize par rotor horizontal ; le modèle emploie ces nombres natifs. Le devenir des autres blocs posés n’a pas été audité indépendamment. Cela ne signifie pas une demi-puissance par bloc.
- Chaque banque de propulsion testée contient une seule hélice, pas deux moteurs groupés. Le tricoptère ne démontre aucune autorité de lacet. Les RPM signés, retours d’inverseur et demandes reçues sont instrumentés dans les derniers cas, sans inventer d’acquittement matériel disponible au Lua.
- Enveloppe du ballon : 1452 m³. Le réglage brûleur est réellement plafonné à 500 m³ par `hot_air_burner_max` ; le dernier cas relit la valeur native après affectation et la pression réelle. Une tentative préalable restait verrouillée parce que son modèle utilisait la capacité d’enveloppe : elle ne compte pas comme essai en vol. Quand le brûleur coupe, le fournisseur de gaz peut se désassocier ; une mesure absente n’est pas un volume nul et les courbes masquent cette absence.
- Le ballon vertical oscille encore : erreur maximale de 1,28 m au maintien, 3,63 m en montée, 4,29 m en descente. La cause unique n’est pas démontrée ; dynamique du gaz, modèle et équilibre doivent encore être travaillés. Le ballon propulsé nécessite aussi une reprise du montage/modèle avant essai libre.
- Aucun réglage PID entre véhicules, aucune modification du Lua de production. Sources créatives à 256 RPM, carburant non limitant, ballon préchauffé. Pas de démarrage à froid, charge suspendue, changement volontaire de masse/centre de masse en vol, hélicoptère, hexacoptère ou octocoptère validés ici. Les limites de déplacement du banc sont des limites d’essai, pas des plafonds ajoutés au pilote.
- Les lectures automatiques du centre de masse, des voiles et de l’enveloppe viennent de l’instrumentation Java du banc ; elles ne deviennent pas des fonctions du SDK Lua Sputnik.

Les prochains correctifs doivent cibler le freinage/retour au maintien du tricoptère, la coordination des virages diagonaux du quad hybride et la dynamique de sustentation du ballon. Ces essais identifient les échecs ; ils ne les corrigent pas encore.
