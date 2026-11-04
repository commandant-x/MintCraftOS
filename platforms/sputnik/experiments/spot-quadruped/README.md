# Quadrupède expérimental piloté par Sputnik

Ce prototype Minecraft inspiré de Spot possède quatre pattes à trois axes, deux segments porteurs de sept blocs par patte et un seul moteur créatif. Douze embrayages sélectionnent les axes, un inverseur fournit le sens commun et treize récepteurs Create Redstone Link les relient au graphe Sputnik. Les axes sont actionnés successivement. Le châssis rectangulaire et les contrepoids restent ceux d'un banc mécanique expérimental : son apparence n'est pas encore une reproduction finie de Spot.

[Télécharger le monde et les TXT](quadrupede-sputnik.zip) · [Vue du monde Sputnik dans Minecraft](screenshots/quadrupede-sputnik.png) · [Vue de dessus](screenshots/quadrupede-dessus.png) · [Commande Sputnik et fréquences](controller/README.md)

## Ouvrir et commander

Extraire `Quadrupede-Sputnik/` dans le dossier `saves` de VENATOR 1.0.0 avec ses mods, notamment Transmission & Linkage 0.2.9. Conserver le dossier `sublevels/`. Le robot est près de `42 180 42` ; en spectateur, `/tp @s 75 198 78 135 23` donne une vue générale. Le moteur créatif et Sputnik sont sur le châssis, vers `20 180 31`. Le moteur est sauvegardé à 0 tr/min et les cases Sputnik décochées.

Le graphe et ses récepteurs sont déjà en place. Vérifier que les douze récepteurs d'embrayage reçoivent 15, puis régler le moteur à 4 tr/min, ouvrir Sputnik et cocher « Armer les commandes redstone », puis « Lancer les huit mouvements ». Décocher la seconde case pour pouvoir relancer. Désarmer et arrêter le moteur après l'essai. Voir les fréquences et les sources dans [controller](controller/README.md).

**Une perte de liaison redstone peut engager un embrayage : le montage ne dispose pas d'un arrêt de sécurité sur perte de signal.** Laisser le moteur arrêté pendant la vérification des liaisons.

## Mesures réalisées

- Les [douze axes](dynamic/analysis.json) ont chacun été entraînés dans les deux sens puis ramenés, à 4 tr/min et châssis maintenu ; les autres axes restaient arrêtés.
- En [position debout](standing/analysis.json), tous les corps étaient déverrouillés, sans guide, moteur arrêté. Les quatre pieds ont déclenché des callbacks de collision. En 220 ticks, variation verticale du châssis inférieure à 0,005 bloc et variation d'orientation inférieure à 0,014°. Les callbacks ne mesurent pas la répartition des charges.
- Le premier [essai de marche ample](gait-first/analysis.json) a fait tomber le robot au deuxième mouvement. Deux essais à amplitude réduite ont ensuite réalisé huit mouvements et environ 2,39 blocs, avec variation d'orientation maximale de 5,95°. Un [essai prolongé](gait-long/analysis.json) a réalisé seize mouvements et environ 4,93 blocs, avec variation maximale de 12,71°. Ces essais utilisaient des commandes redstone injectées par le fixture.
- Dans l'[essai Sputnik](sputnik-ui/analysis.json), le fixture a changé les cases de l'interface, puis Sputnik a piloté les treize récepteurs réels. Huit mouvements ont parcouru environ 2,73 blocs ; la variation d'orientation maximale était de 5,97°. Les douze récepteurs étaient refermés et le moteur arrêté à la fin. Les pieds et le châssis étaient libres, sur un sol instrumenté ; ce sol a été remplacé par de la pierre ordinaire dans le monde livré.
- Après [rechargement](sputnik-reload/samples.tsv), les douze pivots, les treize récepteurs, les deux nœuds et leurs connexions étaient présents, les cases décochées et le moteur arrêté. Une [nouvelle séquence sur cette sauvegarde rechargée](sputnik-replay/analysis.json) a réalisé huit mouvements sur pierre ordinaire : environ 2,92 blocs et 5,27° de variation d’orientation maximale, sans franchir le seuil d’arrêt.

Ces résultats concernent un robot sans joueur ni charge variable sur sol plat. La commande suit une chronologie fixe sans retour de contact, d'angle ou d'équilibre ; les essais ne démontrent pas une marche robuste et continue, ni son comportement sur terrain irrégulier. Les mesures et sources des fixtures sont conservées dans ce dossier et dans `tools/minecraft-world-test/spot-quadruped/`.
