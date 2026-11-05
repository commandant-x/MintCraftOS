# Quadrupède fonctionnel : articulation et perception

Objectif : une machine à quatre pattes efficace, sans objectif de ressemblance à Spot. Contraintes conservées : un moteur créatif, trois pivots commandables par patte, deux segments de sept blocs, pied slime, masse totale cible 10 000 unités et aucun mod ou datapack ajouté. Ces essais utilisent une instrumentation temporaire sur copies isolées ; aucun de ces bancs n'établit une marche rapide ou un évitement autonome.

## Patte isolée et réserve d'extension

Le banc [FunctionalLegExtensionProbe](../../../../tools/minecraft-world-test/spot-transmission/FunctionalLegExtensionProbe.java) part d'une patte isolée portant ses trois pivots, trois embrayages, trois inverseurs et trois réducteurs 2:1, avec un pied slime. Il réemploie la transmission éprouvée : ce n'est pas encore une architecture mécanique entièrement nouvelle. La racine est maintenue et la patte est sans charge ; le banc mesure ses orientations et la position physique du pied.

À moteur 128 tr/min et axe 64 tr/min, quatre impulsions de deux ticks font passer le genou d'environ 0° à 153,6°, puis les quatre impulsions inverses le ramènent à 0° ([trace](functional-leg-extension-v1/poses.csv)). Dès la première impulsion, la flexion atteint 38,4° et le pied monte d'environ 1,40 bloc, mais il se décale aussi d'environ 4,04 blocs. Quatre impulsions conduisent à une flexion excessive : il faut limiter l'amplitude.

Un second essai à moteur 32 tr/min et axes 16 tr/min fait tourner la hanche en sens contraire, pendant les deux premières des quatre impulsions de genou. La flexion mesurée est de 38,40°, le pied monte d'environ 0,75 bloc et se décale de 0,16 bloc suivant la marche ; il revient à moins de 0,002 bloc de sa position initiale après retour des articulations ([trace des pieds](functional-leg-balanced-v1/foot.csv), [orientations](functional-leg-balanced-v1/poses.csv)). C'est une réserve d'extension géométrique sur un essai sans charge ; elle n'établit pas que le robot de 10 tonnes puisse utiliser cette course, ni que les pieds adhèrent. Le fonctionnement avec le moteur à 128 tr/min et une réduction supplémentaire n'est pas encore intégré sur cette patte.

## Capteur optique présent dans le pack

Le capteur `simulated:optical_sensor`, déjà inclus via Simulated dans le modpack, a été testé sans installer de nouveau mod de gameplay. Un lien redstone Create placé au-dessus transmet son signal à un nœud Lua natif Sputnik. Chaque cas ci-dessous est un essai fixe ; distance mesurée depuis le centre du capteur vers la face touchée.

| Cible | Distance | Signal redstone reçu dans Sputnik |
| --- | ---: | ---: |
| Air | aucune, portée réglée à 15 | 0 |
| Pierre | 3,5 blocs | 12 |
| Pierre | 7,5 blocs | 8 |
| Pierre | 11,5 blocs | 4 |
| Feuilles de chêne | 7,5 blocs | 8 |
| Verre | non détecté dans cet essai | 0 |
| Air, deuxième passage | aucune | 0 |

[Résultats complets](native-optical-v3/results.csv), [événements](native-optical-v3/events.tsv), [banc](../../../../tools/minecraft-world-test/spot-sensing/NativeOpticalSensorProbe.java). Le verre est une limite concrète de ce test. Le signal est quantifié, dépend de la portée configurée et ne décrit que le rayon pointé : il ne constitue pas une carte du terrain. Le capteur, son orientation, ses angles morts, les sols en pente, la pluie, la charge et le lien avec les sous-structures mobiles restent à tester en mouvement avant tout évitement. Une première tentative de banc a échoué à cause d'une propriété de direction incorrecte ([erreur](native-optical-v2/error.txt)).

## Première pose coordonnée sur quatre pattes

Sur une copie du châssis expérimental à entraxe 14 × 24, masse totale mesurée 10 000, une commande synchronise deux impulsions de hanche et quatre de genou sur les quatre pattes. Moteur à 32 tr/min, axes à 16 tr/min, sol plat, sans poussée. La flexion physique après stabilisation vaut environ 38,2°, 40,3°, 41,2° et 40,8° selon la patte. Du tick 380 au tick 2525, l'inclinaison maximale est 1,21° et la finale 0,46° ; le châssis descend de 0,68 bloc ([positions](quad-compact-combined-pose-v1/stand.csv), [angles](quad-compact-combined-pose-v1/drive.csv)). Les positions des pieds ne prouvent pas le contact ou l'adhérence.

Dans un second essai identique, la commande inverse ensuite les mouvements de hanche et de genou : de tick 950 à 1250 le corps monte de 180,778 à 181,476, soit environ 0,70 bloc ; l'inclinaison est passée de 0,28° à 0,11° ([positions](quad-compact-combined-extend-v1/stand.csv), [angles](quad-compact-combined-extend-v1/drive.csv)). C'est un essai d'extension à l'arrêt sur sol plat et sans perturbation, pas encore un rattrapage ni une marche. Les réducteurs 128 → 16 ne sont pas intégrés : le moteur a été ralenti temporairement à 32 tr/min pour ces tests.

## Première marche à partir de la pose fléchie

Le prototype `gait-combined-v1.lua` prépare cette pose puis commande une patte à la fois, en cycles de 24 ticks. Sur sol plat, entre les ticks 980 et 1480, le châssis a parcouru 7,68 blocs nets en 25 secondes de jeu à 20 TPS, soit 0,31 bloc/s ; progression selon z −7,62 blocs, inclinaison maximale 1,79°, variation de hauteur +0,12 bloc ([positions](quad-compact-gait-v1/stand.csv), [transmissions](quad-compact-gait-v1/wireless.csv)). Les huit axes de hanche et de genou ont effectivement tourné pendant la fenêtre ; les axes latéraux sont restés immobiles. Le déplacement peut inclure du glissement : aucun contact des pieds n'est mesuré. Il s'agit d'un unique essai à moteur 32 tr/min, loin de la vitesse visée et sans obstacle.

Avec un cycle de 16 ticks et les mêmes conditions, un essai a donné 13,60 blocs nets en 25 secondes de jeu, soit 0,54 bloc/s ; inclinaison maximale 2,54° et variation de hauteur +0,04 bloc ([positions](quad-compact-gait-fast-v1/stand.csv), [transmissions](quad-compact-gait-fast-v1/wireless.csv)). Cela dépasse le résultat du cycle de 24 ticks dans ces deux essais uniques, sans démontrer la vitesse maximale ou un fonctionnement sur terrain irrégulier.

Un cycle de 12 ticks a parcouru 26,39 blocs nets en 25 secondes de jeu, soit 1,06 bloc/s ; inclinaison maximale 2,39°, variation de hauteur −0,01 bloc, et 166 ticks où une hanche ou un genou était entraîné ([positions](quad-compact-gait-faster-v1/stand.csv), [transmissions](quad-compact-gait-faster-v1/wireless.csv)). Chaque cadence a été essayée une seule fois et le déplacement peut inclure du glissement. La vitesse reste très inférieure à 10 blocs/s et n'a pas été testée sur obstacles.

## Premier arrêt devant un mur avec capteur embarqué

Le capteur optique et son émetteur Create ont été placés sur le châssis ; un mur de pierre fixe était devant lui. Après la pose fléchie, la marche à cycle de 12 ticks s'est déclenchée. Au tick 1028, le capteur indiquait 10,21 blocs jusqu'au mur et envoyait une puissance de 6 ; Sputnik a enregistré 6 et a verrouillé l'arrêt de la marche. Cinq ticks après cet ordre et jusqu'à la fin, aucun pignon de hanche ou de genou n'est enregistré en rotation. Le corps a encore bougé de 1,06 bloc après l'ordre, et le capteur indiquait 9,25 blocs en fin d'essai ([capteur](quad-compact-optical-stop-v1/optical.csv), [position](quad-compact-optical-stop-v1/stand.csv), [transmissions](quad-compact-optical-stop-v1/wireless.csv)). La mesure est celle du capteur vers la face touchée, pas une distance de sécurité entre le robot entier et le mur.

Ce seul essai montre un arrêt devant un mur de pierre, pas son contournement, la détection du verre, d'un trou ou de tous les obstacles. Le signal 0 peut signifier absence de cible ou absence de liaison : ce montage n'a pas de surveillance de perte de liaison et ne peut pas être considéré comme sûr en cas de capteur déconnecté. Les essais portent sur des copies, avec instrumentation temporaire ; les seuls blocs de perception et de communication sont déjà dans le pack.

Dans un témoin identique sans mur, le capteur n'a signalé aucun impact et la commande n'a déclenché aucun arrêt sur 2 176 mesures ; le robot a parcouru 25,85 blocs nets pendant la même fenêtre de 25 secondes de jeu ([capteur](quad-compact-optical-clear-v1/optical.csv), [positions](quad-compact-optical-clear-v1/stand.csv)). Ce témoin et l'essai avec mur sont uniques et ne prouvent pas l'absence générale de faux positifs ou négatifs.

Un essai à cycle de huit ticks a parcouru 20,66 blocs nets en 25 secondes de jeu, soit 0,83 bloc/s, avec 2,25° d'inclinaison maximale ; les transmissions enregistrent 248 ticks d'activité d'une hanche ou d'un genou ([positions](quad-compact-gait-8-v1/stand.csv), [transmissions](quad-compact-gait-8-v1/wireless.csv)). Dans ces essais uniques, augmenter la cadence de 12 à 8 ticks ne donne donc pas une meilleure progression. Le cycle de 12 ticks est conservé comme point de départ expérimental.
