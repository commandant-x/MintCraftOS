# Parcours de 250 blocs du quadrupède Sputnik

Le parcours est une piste de pierre de 57 blocs de large, avec un repère vert au départ et un repère rouge 250 blocs plus loin dans la direction positive de Z. Le châssis du robot commence vers `40 182 42`. Sept bandes transversales d'obstacles couvrent la piste principale : tapis en Z=64, dalles en Z=82 et 112, bloc entier en Z=152, dalle en Z=202, bloc entier en Z=252 et dalle en Z=286. Elles sont suivies de la ligne d'arrivée à Z=292. L'obstacle Z=286 se trouve juste avant l'arrivée du châssis ; la sortie complète du robot au-delà de cette ligne demanderait davantage de déplacement.

[Monde Minecraft et consignes](quadrupede-parcours-250.zip) : extraire `Quadrupede-Parcours-250/` dans `saves` de VENATOR 1.0.0 avec tous ses mods. Conserver `sublevels`. Les commandes Sputnik sont déjà raccordées ; le moteur est arrêté au départ. La [documentation du robot](../spot-quadruped/README.md) décrit l'interface et les récepteurs.

Le robot est un prototype à un moteur et douze axes sélectionnés successivement. Sa marche est temporisée, sans détection d'obstacle, direction autonome ni contrôle d'équilibre. Une perte de liaison peut engager un embrayage : le moteur doit être arrêté lors de la vérification des récepteurs.

Les résultats réels sont conservés dans `trial/` ; le parcours construit n'implique pas que le robot l'a terminé. La construction initiale est vérifiée dans `build/`, avec un moteur à l'arrêt, douze embrayages fermés et les treize corps déverrouillés.

## Premier essai : résultat mesuré

Depuis une copie du monde du parcours, les cases de l'interface Sputnik ont été actionnées par le fixture ; chaque séquence de huit mouvements a été relancée après la précédente. Le châssis a progressé de **14,40 blocs en Z**, avec 3,96 blocs de déplacement latéral. L'arrêt automatique du banc s'est déclenché après un changement d'orientation total de **25,19°**, sans chute du châssis (baisse verticale maximale mesurée : 0,107 bloc). Ce seuil porte sur la variation d'orientation complète, notamment la rotation horizontale, et non uniquement sur l'inclinaison. Le pied le plus avancé a dépassé la position Z du premier tapis ; la mesure ne démontre pas que tout le robot a franchi l'obstacle. Aucune dalle ni aucun bloc entier n'a été atteint par un pied.

La piste de 250 blocs existe, mais **le quadrupède n'a pas encore parcouru les 250 blocs**. Les mesures, le motif d'arrêt et le programme du banc sont dans [trial](trial/). Une version expérimentale de la chronologie vise à limiter l'asymétrie et est soumise à un essai séparé ; elle n'est pas installée dans le monde livré.

## Réglage de trajectoire expérimental

Un [second essai](tuned/analysis.json) modifie les durées des hanches arrière gauche et avant gauche. Au même tick que l'arrêt du premier essai, il a avancé de 7,57 blocs, avec 0,55 bloc de dérive latérale et 2,86° de changement d'orientation, contre 14,40 blocs, 3,96 blocs et 25,19° pour la commande d'origine. Il a ensuite atteint la limite de durée prévue au tick 7480 : 9,81 blocs parcourus en Z, changement maximal d'orientation de 4,48°, sans franchir le seuil d'arrêt. Les séquences ont été relancées par le banc, et les récepteurs ont confirmé les durées demandées. À 20 ticks par seconde, 9,81 blocs en 360 secondes représentent environ **0,027 bloc par seconde**.

Le pied le plus avancé a atteint la coordonnée du tapis, mais pas l'ensemble du robot ; le franchissement n'est pas démontré. Le [TXT expérimental](gait-experimental.clipboard.txt) est fourni séparément et n'est pas installé par défaut dans le monde : il n'a pas été qualifié sur les obstacles ni pour 250 blocs.

## Campagne de vitesse

Les vitesses ci-dessous sont des déplacements moyens du châssis en direction Z, calculés sur le temps de jeu nominal à 20 ticks/s ; un serveur ralenti donne une vitesse inférieure en secondes réelles. Chaque essai part d'une copie du même monde, avec le robot sans charge et des séquences relancées par le banc.

| Commande expérimentale | Résultat | Vitesse moyenne vers l'arrivée | Observation |
| --- | --- | --- | --- |
| [4 tr/min](tuned/analysis.json) | 9,81 blocs en 360 s | 0,027 bloc/s | Limite de durée, variation d'orientation maximale 4,48° |
| [8 tr/min](speed-8rpm/analysis.json) | 13,57 blocs en 180 s | 0,075 bloc/s | Limite de durée, variation d'orientation maximale 10,44° |
| [16 tr/min, premier réglage](speed-16rpm/analysis.json) | 15,53 blocs en 54,4 s | 0,285 bloc/s | Arrêt après une baisse verticale de 2,04 blocs ; ce réglage n'est pas stable |
| [16 tr/min, impulsions symétriques](speed-16rpm-symmetric/analysis.json) | 9,12 blocs en 90 s | 0,101 bloc/s | Limite de durée, variation d'orientation maximale 13,22° |
| [32 tr/min, impulsions entières](speed-32rpm/analysis.json) | 5,66 blocs en 45 s | 0,126 bloc/s | Limite de durée, variation d'orientation maximale 18,04° |
| [64 tr/min, chronologie 32 tr/min](speed-64rpm/analysis.json) | 14,22 blocs en 12,25 s | 1,161 bloc/s | Arrêt au seuil d’orientation de 25° ; vitesse non stable |
| [128 tr/min, chronologie 32 tr/min](speed-128rpm/analysis.json) | 14,92 blocs en 17,1 s | 0,873 bloc/s | Arrêt au seuil d’orientation de 25° ; vitesse non stable |
| [256 tr/min, chronologie 32 tr/min](speed-256rpm/analysis.json) | 0,72 bloc en 6,55 s | 0,110 bloc/s | Arrêt au seuil d’orientation de 25°, dérive latérale de 2,50 blocs |

Les traces des récepteurs montrent que les impulsions de certaines articulations étaient alternativement de deux et trois ticks au premier essai à 16 tr/min. Le réglage corrigé utilise une durée égale à l'aller et au retour pour chaque axe ; cela coïncide avec une meilleure tenue sur cet essai, sans établir à lui seul la cause de la perte de hauteur précédente. Aucun essai n'a validé 25 blocs/s, ni le franchissement complet du parcours ou d'un obstacle. Les pics de vitesse sur un seul tick, inclus dans les analyses, peuvent provenir d'oscillations ou de glissements et ne constituent pas une vitesse de marche soutenue.

Le monde livré conserve la commande d'origine réglée pour 4 tr/min. Les graphes alternatifs [8 tr/min](gait-experimental-8rpm.clipboard.txt) et [16 tr/min symétrique](gait-experimental-16rpm-symmetric.clipboard.txt) et [32 tr/min](gait-experimental-32rpm.clipboard.txt) sont fournis à part pour expérimentation ; les essais ne prouvent pas leur sûreté générale, leur comportement sous charge ou leur capacité sur tout le parcours.
