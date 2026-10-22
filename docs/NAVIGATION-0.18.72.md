# Navigation 0.18.72 — calibration mesurée et géométrie réelle

## Mise à jour

Depuis CraftOS :

```lua
wget run https://raw.githubusercontent.com/commandant-x/MintCraftOS/main/install.lua
```

Redémarrer ensuite le Computer. Le mode par défaut ne conserve pas de nouvelle
version antérieure ; la transaction temporaire protège les écritures interrompues.
Les anciennes sauvegardes déjà présentes ne sont supprimées que par la purge
explicite prévue dans Update. Les documents personnels sont conservés.

Pour la coque, remplacer **sur le serveur et les clients** le Vehicle Bridge par
`addons/vehicle-bridge/dist/mintcraft-vehicle-bridge-1.21.1-0.2.2.jar`, puis redémarrer
Minecraft. Ne garder qu'une version du bridge dans `mods`. Le JAR n'occupe pas le
disque du Computer. Le bridge 0.2.1 reste suffisant pour les brûleurs et les RX,
mais ne fournit pas le nouveau relevé des blocs.

## Une séquence de calibration

1. Navigation → Vehicle / setup : détecter le véhicule et enregistrer le groupe
   de brûleurs. L'identité et les positions viennent du bridge, sans saisie.
2. Pour les deux moteurs : Vehicle / setup → Motor links. Activer le groupe,
   sélectionner le transmetteur détecté et les six fréquences RX distinctes :
   clutch, transmission et inverseur pour gauche et droite. Enregistrer.
   Le débrayage est par défaut à 15 ; le choix 0 existe pour un montage inversé.
   Les fréquences doivent aussi être distinctes de celle des brûleurs.
3. Altitude → Start sequence : lire puis confirmer le vol de mesure, dans une zone
   dégagée. La confirmation inclut les mouvements verticaux, le test de secours,
   les essais moteurs et le court trajet de vérification lorsque les moteurs
   sont configurés. Garder Navigation ouverte.
4. Suivre le résultat dans le même tableau. La séquence initialise les brûleurs,
   vérifie leur retour, teste le signal de secours puis mesure les hauteurs.
   Chaque palier exige huit mesures fraîches avec |vitesse verticale| ≤ 0,1 m/s
   et une dispersion de hauteur ≤ 0,5 m. Aucun délai maximal de palier ou de
   sweep n'est ajouté. Les défauts de communication restent des arrêts réels.
5. Si les mesures permettent un modèle qualifié, la séquence vérifie le maintien
   d'altitude, une descente, une montée, le retour, une réponse physique au secours,
   puis la priorité du STOP logiciel et la récupération. Pour tenir compte de la
   modulation entre niveaux redstone entiers, ces tests de maintien exigent huit
   échantillons, une vitesse moyenne absolue ≤ 0,1 m/s, une vitesse instantanée
   absolue ≤ 0,25 m/s et une dispersion de hauteur ≤ 0,5 m.
6. Avec les moteurs, les 60 combinaisons gauche/droite × signaux 1…15 × inverseur
   sont observées. Le signal 0 et le débrayage servent à mesurer le freinage.
   Les changements passent par débrayage confirmé, changement confirmé,
   réembrayage ; un accusé du transmetteur seul ne suffit pas.
7. Les réponses avant/arrière, le lacet et le freinage doivent être observables.
   Un court trajet à deux points vérifie ensuite le guidage et l'arrêt réels.
   Seulement après réussite, Route reconnaît la calibration de la session et
   permet un trajet confirmé avec l'altitude dans la plage mesurée.

Le rapport borné remplace `/system/config/navigation-calibration.cfg` ; il ne crée
pas d'historique. La permission d'autopilote et la confirmation restent nécessaires
pour les trajets suivants. La preuve d'actionnement n'est pas restaurée au boot :
elle est liée au propriétaire, au véhicule, aux fréquences et à la masse mesurée.
Un changement de masse de plus de 2 % invalide la preuve pour les moteurs.

F10 / STOP déclenche le secours, y compris après la fin du sweep pendant un maintien
d'altitude. Fermeture de Navigation, perte de propriétaire, permission retirée,
retour RX absent, télémétrie périmée ou commande physique active arrêtent la
séquence. Un STOP extérieur ne peut pas être repris par la séquence automatique.

Les tests automatiques ne prétendent pas qu'un **interrupteur physique indépendant**
a été testé : ce champ reste « not observed » et les anciens indicateurs de
validation manuelle ne sont pas falsifiés. La topologie des arbres/clutches et
les fréquences ne permettent pas de déduire automatiquement leur rôle physique :
les six affectations initiales sont à choisir une fois. Les RPM ne sont pas
inventés à partir de 256 RPM ; le guidage utilise les mouvements observés.

## Coque 2D et 3D

Vehicle / setup → Diagram lance automatiquement le relevé de la coque. Les boutons
Top, Side, Front, 3D et Rotate changent la projection. Cutaway et Layer-/Layer+
retirent les couches au-dessus de la hauteur choisie pour inspecter l’intérieur. Zoom et sélection des
équipements restent disponibles. Cliquer sur un bloc dans le rendu natif affiche
son état et ses coordonnées locales ; Scan hull relance le relevé après modification.

Le relevé comprend tous les blocs non air des sections chargées du plot parent,
avec positions **entières des coins**, identifiant et propriétés de bloc. Les
équipements gardent leurs positions de centre (+0,5 bloc), leur direction mesurée
et le centre de masse dans le même repère. Les runs compressés sont sans perte ;
le dessin 3D affiche le volume des voxels avec faces et ordre de profondeur, sans
reconstruire une coque imaginaire autour des seuls équipements. Les surfaces
intérieures sont incluses dans les données, même si la projection les masque.

Il s'agit d'une géométrie **par blocs**, pas des maillages décoratifs ou des formes
de collision détaillées de chaque slab/propeller. Les connexions d'arbres et les
forces aérodynamiques ne sont pas déduites de la simple proximité.

Le bridge lit au plus une section 16³ par appel et un appel par tick ; le Computer
utilise un worker séparé à 4 Hz, sans ralentir intentionnellement les retours
brûleurs. Aucun chunk n'est chargé, aucun bloc ni sortie n'est modifié. Les limites
sont 128 chunks et 1024 sections côté bridge ; 65 536 blocs et 2 Mio encodés en RAM
côté Computer. Une limite ou un chunk manquant affiche explicitement une couverture
partielle. Le relevé reste en RAM, sans remplir le disque de 1 Mo.

« Complete » concerne seulement la couverture du plot parent chargé. Les enfants
Sable et contraptions mobiles ne sont pas fusionnés : leur géométrie reste hors
périmètre. Un relevé paginé couvre un intervalle, pas un instant atomique ; un
changement de disposition des sections l'invalide. Les changements au sein d'une
section déjà lue nécessitent Scan hull. Ce relevé ne sert pas de détecteur
d'obstacles pour les vols.

## Validation

Tests Lua sur source et paquet compact, simulation du service avec deux moteurs,
retours RX, séquence de transmission, essais d'altitude et trajets. Bridge compilé
contre Sable 2.0.6, Aeronautics 1.3.2, Create 6.0.10 et CC:Tweaked 1.120.2, avec tests
Java de codec et de contrat sans mutation/chargement de chunks. Ces tests ne
remplacent pas un essai dans Minecraft avec le montage réel.

Résultats du paquet final : 156 suites Lua réussies sur source et sur version
compactée (puis contrôles ciblés des derniers ajustements de rendu), 10 tests Java.
Sur le système de fichiers simulé à quota 1 000 000 octets : 873 356 octets occupés
avec 100 000 octets de données personnelles ; pic de migration depuis 0.18.71 à
965 819 octets en mode sans historique. Les données réelles de chaque Computer
peuvent changer la place disponible ; la prévision reste vérifiée avant écriture.
