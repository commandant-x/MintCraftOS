# Quadrupède : comprendre un arbre et s'arrêter

> **Archive d’un essai abandonné :** ce prototype dépend d’un mod ajouté et ne répond pas à la contrainte actuelle. Ne pas installer ce capteur ni utiliser ce monde pour la version sans ajout. Voir l’expérience [sans mod supplémentaire](../spot-quadruped-native-sensing/README.md).

Cette expérience reprend le robot à un moteur créatif, quatre pattes de trois axes et quatre pieds en slime. Le mod optionnel [capteur Sputnik](../../../../addons/sputnik-obstacle/README.md) ajoute le nœud « Terrain avant - quadrupede ». Il observe les blocs statiques déjà chargés devant le châssis. Un bloc non-air est traité comme un obstacle ; du bois et des feuilles proches donnent un indice d'arbre possible, pas une identification certaine. Il ne détecte pas les entités ou les structures mobiles et ses dimensions sont propres à ce robot.

## Installer et essayer le monde

Télécharger [le monde avec l’arbre](quadrupede-arbre.zip) et [le mod du capteur testé](mintcraft-sputnik-obstacle-0.1.0.jar). Installer le jar dans `mods` de l’instance VENATOR 1.0.0 ; en multijoueur, installer la même version sur le client et sur le serveur. Extraire le dossier `Quadrupede-Arbre` dans `saves` en gardant son dossier `sublevels`. Le robot se trouve près de `40 182 42` et l’arbre près de `40 166 84`. Le moteur est enregistré à 0 tr/min et les commandes sont désarmées.

Après avoir vérifié que les douze récepteurs d’embrayage sont alimentés à 15, régler le moteur à 8 tr/min ; dans Sputnik, cocher « Armer les commandes redstone », puis « Lancer les huit mouvements ». Décocher la seconde case avant une nouvelle séquence. Si le robot détecte l’arbre ou si la mesure n’est plus valide, il ferme ses embrayages et mémorise l’arrêt ; désarmer et arrêter manuellement le moteur. Après rechargement, le graphe et les trois connexions du capteur ont été retrouvés et l’arrêt a été testé de nouveau ([traces](reload-check/events.tsv)). Les blocs d’arbre ont aussi été vérifiés dans la sauvegarde ; le banc reconstruit sa piste et l’arbre pour l’essai de rechargement.

## Résultats dans Minecraft

Le banc a vérifié à l'arrêt un arbre en rondins et feuilles, une pierre, des feuilles seules et une zone dégagée. Il a reconnu l'arbre possible uniquement dans le premier cas. Voir [recognition/events.tsv](recognition/events.tsv).

Pendant la marche à 8 tr/min, le capteur a repéré la cime puis indiqué un arbre possible. Le contrôleur a demandé l'arrêt ; dix ticks plus tard, les douze récepteurs d'embrayage étaient alimentés à 15 et les douze vitesses de pignons d'articulation valaient zéro. Le banc a alors arrêté le moteur. Progression du châssis : 4,83 blocs ; détection du premier feuillage à 23,75 blocs du début du volume de balayage. Voir [tree-approach/events.tsv](tree-approach/events.tsv), [sensor.csv](tree-approach/sensor.csv) et [wireless.csv](tree-approach/wireless.csv). Le calcul de distance ne mesure pas une distance exacte entre le pied et l'arbre.

Au premier essai de contournement, à 16 tr/min, aucun embrayage ne s'est ouvert et la progression était nulle après 90 secondes de jeu ; le contournement n'a pas été démontré. Les traces sont conservées dans [bypass-first-attempt](bypass-first-attempt/). Après correction de l’ordre des entrées, le second essai a bien lancé le contournement : objectif latéral +16 blocs, déplacement observé environ +3,14 blocs, progression de 19,97 blocs. Quand la distance au début du volume de balayage est tombée à 5,98 blocs, les douze embrayages se sont fermés et le banc a arrêté le moteur. L’arbre n’a pas été contourné. Voir [bypass-second-attempt](bypass-second-attempt/). Le programme `gait-bypass-experimental.lua` reste une piste de recherche.

Le contrôleur d'arrêt `gait-terrain-stop.lua` referme les commandes si la détection est positive ou invalide, ou si l'échantillon date de plus de dix ticks ; il mémorise cet arrêt jusqu'au désarmement. Il ne coupe pas le moteur : le joueur doit l'arrêter. Les tests Lua couvrent obstacle, mesure périmée et mesure invalide. Une coupure radio peut engager un embrayage : cette expérience n'est pas un arrêt de sécurité matériel.

Le premier essai d'approche, conservé dans [first-approach](first-approach/), a rencontré le feuillage avant que le tronc entre dans la zone de recherche et a déclenché une assertion du banc. Le capteur a ensuite été complété par une recherche locale limitée aux chunks chargés ; un signalement de feuillage seul suffit dans tous les cas à déclencher l'arrêt prudent.

La vitesse cible de 10 blocs/s, le franchissement ou contournement autonome des obstacles et les 250 blocs du parcours restent à démontrer. La piste de cette expérience contient un arbre isolé ; les bandes d'obstacles transversales ont été enlevées pour étudier ce cas.
