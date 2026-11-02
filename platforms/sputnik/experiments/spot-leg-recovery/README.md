# Patte Spot : contrepoids, inversion et contact au sol

Prototype Minecraft d'une seule patte : deux segments de sept blocs, trois pivots, un moteur créatif, trois embrayages et un inverseur Create commandés par redstone. Une poutre expérimentale de cinq blocs, dont trois blocs de fer, sert de contrepoids sur le premier segment mobile. Elle améliore le comportement de la hanche mais reste encombrante et n'est pas une intégration définitive dans le corps de Spot.

[Capture dans Minecraft](screenshots/patte-equilibree.png) · [Monde expérimental](spot-patte-equilibree.zip) : extraire son dossier de monde dans `saves` du pack VENATOR 1.0.0 avec Transmission & Linkage 0.2.9. Le ZIP contient des instructions et conserve `sublevels/`. Le moteur est arrêté ; la construction se trouve vers `32 180 32`. Un embrayage alimenté par redstone coupe sa branche. L'inverseur est commun : pour commander des axes dans des sens opposés, il faut les sélectionner à tour de rôle. Les signaux de ces essais sont produits par des blocs de redstone placés par le fixture ; aucun Sputnik ni télécommande n'est fourni dans ce monde.

## Essais en suspension

Le [banc équilibré](balanced-reverse/analysis.json) a commandé successivement les trois embrayages dans les deux sens avec le moteur à 4 tr/min. Le pignon sélectionné a changé de signe et les deux autres pignons sont restés à zéro. Les angles mesurés à l'aller sont environ 50,1°, −48,0° et −48,0° ; les angles de retour sont environ −49,7°, +48,0° et +48,0°. Il s'agit d'un aller-retour isolé par axe, sans charge de châssis ni marche, et non d'une qualification de stabilité à long terme.

Les essais avec les réglages de pivot d'origine et une simple réduction de vitesse ne suffisaient pas pour la hanche latérale. Un [contrepoids seul](counterweight/analysis.json) a rapproché cette hanche de la consigne. Des [réglages de rigidité expérimentaux](stiffness-48k/analysis.json) ont été testés séparément pour comprendre l'effet ; ils ne sont pas livrés ni imposés. Les fichiers de configuration d'origine ont été restaurés.

## Sauvegarde

La première réouverture retrouvait les trois pivots et corps malgré les messages Sable ([relevé](reload-original/samples.tsv)). Le fixture d'assemblage avait ajouté trois tickets de chargement forcé. Après leur retrait sur une copie, les trois corps restaient présents ([tickets et relevé](ticket-release/)). Au redémarrage suivant, le journal ne contenait plus les erreurs `Attempted to snatch sub-level` et le [même aller-retour a été rejoué](balanced-reload/analysis.json) : environ 45,2°, −48,0° et −48,0° à l'aller, avec inversion des trois régimes. Cette vérification porte sur ces redémarrages précis et ne garantit pas tous les chargements futurs.

## Contact

Un [banc de contact](ground-contact/contact-analysis.json) utilise un bloc de sol instrumenté dont le callback Sable est enregistré. Les positions correspondent au segment inférieur et au sol ; des contacts sont relevés après libération de la patte. Dans cet essai la hanche reste attachée au monde : les décomptes sont des événements de contact, pas des mesures de force et ne démontrent pas la portance d'un châssis. Le pied a bougé sur le sol ; un retour de hanche conserve environ 3,5° d'écart dans cet essai. Aucun cycle de marche ni stabilité de robot n'est établi.

Les traces brutes, le code des fixtures dans `tools/minecraft-world-test/spot-leg*` et les analyseurs Python sont disponibles dans le dépôt. Les mondes de test avec blocs de mesure sont jetables et ne sont pas inclus dans le ZIP.

## Essai avec châssis libre : échec de stabilité

Sur un autre [banc](support/analysis.json), les éléments du moteur et du premier pivot sont assemblés dans un petit châssis Sable libre de tomber et de tourner. Les quatre corps sont maintenus initialement, puis tous libérés sous gravité ; une surface instrumentée enregistre le contact du segment inférieur. Avant même la première commande, le châssis s'est déplacé horizontalement d'environ 2,58 blocs. Pendant l'essai il s'est incliné de plus de 45°, est sorti du plateau et est tombé. Ce résultat ne valide pas l'appui d'un châssis ni la marche ; une patte seule sans guidage ni commande d'équilibre ne maintient pas ce châssis dans les conditions testées.

Un [essai complémentaire guidé](guided/analysis.json) utilise une contrainte de test statique qui bloque les translations horizontales et les rotations du châssis, mais laisse la translation verticale libre ; elle ne constitue pas un mécanisme inclus dans le monde livré. Le segment inférieur a touché la surface instrumentée. Le châssis est revenu à environ 0,015 bloc sous sa hauteur initiale à la fin des cycles, après être descendu jusqu'à environ 4,61 blocs sous cette hauteur pendant les mouvements. Ce résultat montre un appui dans les conditions guidées, avec des variations verticales importantes ; il ne prouve ni équilibre libre, ni maintien stable, ni marche.
