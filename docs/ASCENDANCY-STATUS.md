# Autopilot Ascendancy — état du développement

## Périmètre et référence inspectée

Le document utilisateur « PROJECT AUTOPILOT ASCENDANCY » demande de commencer
par le lot A et d'étendre l'existant. `origin/main` a été récupéré et comparé :
référence 0.18.80, commit `7947f2cf7ff31803691d4a6d735e1e31b9ecd947`.
La version 0.18.81 livre un premier incrément **partiel** du lot A.
0.18.82 ajoute [A.2, observations et catalogue](ASCENDANCY-A2-OBSERVATIONS.md),
également partiel : pas de calibration universelle ou de nouveaux axes certifiés.
0.18.83 ajoute [A.3, observations des essais moteur](ASCENDANCY-A3-EXPERIMENTS.md),
sans impulsion supplémentaire ni certification de nouveaux axes. Elle ne livre
ni Autonomy 2.0 complète ni l'ensemble du lot A.

0.18.88 ajoute [A.8, surveillance mécanique](ASCENDANCY-A8-MOTOR-HEALTH.md) :
associations clutch/source observées pendant les essais existants, preuve privée
de session et maintien vertical lors d'une panne horizontale qualifiée. Le lot A
et Autopilot 2 restent incomplets.

0.18.89 ajoute [A.9, contrôle local mesuré](ASCENDANCY-A9-MEASURED-CONTROL.md) :
caractérisation des sorties connues, allocation bornée, essais de retour,
inclinaison identifiée passivement et Bridge 0.3.0. Les lots A–E ne sont pas
terminés ; les limites et essais non effectués sont documentés.

0.18.90 ajoute [B.1, archives et recontrôles](ASCENDANCY-B1-MODEL-REUSE.md) :
reconstruction depuis les preuves, nouvelle qualification, séparation des liaisons
chauffe/moteur et surveillance des changements d’inertie/centre de masse.
Le projet complet reste actif et incomplet.

## Capacités constatées avant cet incrément

| Fonction | Contrat constaté | Limite réelle |
| --- | --- | --- |
| Pose Sable | UUID, pose monde, fraîcheur, vitesse dérivée de deux poses | Pas de capteur de terrain |
| Avionics | Mesures horodatées, altitude, attitude selon API disponible | Un champ absent reste indisponible |
| Vehicle Bridge 0.2.3 | Inventaire/coque du parent chargé, masse, mécanique Create et fréquences | Lecture seule ; coque ≠ obstacle monde |
| Chauffe collective | Groupes de fréquences, initialisation et retours de tous les brûleurs | Un canal logique vertical |
| Altitude automatique | Niveaux physiquement stables, modèle validé, maintien par alternance | Plage mesurée ; pas de garantie de précision absolue |
| Deux banques motrices | Sources cinétiques réelles, 60 modes, quatre recontrôles si modèle réutilisable | Avant/arrière et lacet ; pas six axes |
| Propulseurs/inclinaison | Mapping/PID et vérification manuelle existants | Pas d'identification automatique universelle |
| Adaptation de masse | Correction locale, trajet suspendu, pas de balayage en vol | Ne recertifie ni gains ni moteurs |
| Route/Atlas | Waypoints monde, sélecteur X/Z, confirmation du trajet | Pas de relief ni évitement |
| Sécurité | Propriétaire, permissions, identité, fraîcheur, retours, STOP/F10, arrêt à fermeture | Pas de mission détachée |

## Incrément A.1 livré en 0.18.81

### Identification du sous-espace de commande

`system.navigation.authority.identify` examine une matrice bornée à six axes
et 32 commandes, avec refus des colonnes incomplètes ou non finies. Il recherche
le rang par orthogonalisation répétée et teste si chaque axe appartient
indépendamment au sous-espace mesuré. Une réponse couplée n'est pas assimilée
à plusieurs commandes indépendantes. Les seuils de réponse et le ratio des
pivots sont des diagnostics conservateurs, pas un calcul statistique de précision.

Les essais différentiels existants alimentent réellement l'analyse avant/lacet,
en repère horizontal aligné au cap, en blocs/s² et degrés/s². Ils enregistrent
aussi les réponses latérales et verticales disponibles, sans les certifier.
Aucune fréquence supplémentaire ni nouvelle impulsion de test n'est ajoutée.
Un échec d'identification horizontale laisse le maintien vertical disponible.
Les autres axes ne sont ni supposés nuls ni déclarés contrôlables sans mesure.

### Freinage prédictif

Les arrêts au neutre enregistrent la vitesse initiale, le délai avant le retour
confirmé du neutre et le déplacement maximal observé jusqu'à l'arrêt.
L'enveloppe utilise la décélération équivalente minimale mesurée et le délai
maximal ; elle ne dépasse pas les vitesses réellement observées. Le guidage
réduit sa vitesse avant la zone d'arrivée et borne l'augmentation de consigne
par la réponse d'accélération mesurée. Les limites optionnelles de l'opérateur
et les protections de route existantes restent inchangées.

Les champs de freinage soumis par le client ne sont pas des preuves : `flightd`
les remplace par son modèle privé en mode différentiel et les supprime dans les
modes manuels sans enveloppe qualifiée. Les anciens rapports sans ces mesures
ne produisent pas une enveloppe inventée. Les quatre contrôles de réutilisation
peuvent apporter les nouvelles mesures sans répéter les 60 modes.
Cette enveloppe empirique n'est pas une garantie d'évitement d'obstacles.

### Supervision passive et dégradation

Après la calibration, huit observations fraîches espacées d'au moins 0,5 s
peuvent constater l'absence de translation et de lacet malgré des commandes
motrices confirmées qui devraient produire une réponse mesurable. Le compteur
reste borné ; il ne reçoit ni événement de dessin ni impulsion exploratoire.
Un compteur de diagnostic ne suffit pas à attribuer une panne à un bloc précis.

La navigation horizontale est alors invalidée et les deux clutches désengagés.
L'altitude cible et son contrôleur sont conservés **si les protections verticales
les ont encore validés**. Le système refuse une nouvelle commande horizontale
ou l'export d'un faux modèle valide avant requalification. STOP et les défauts
de capteurs, de propriétaire ou de retour des actionneurs gardent leurs traitements.

`flightd.status()` expose `authority`, `predictiveBraking` et
`horizontalDiagnostic`. L'interface existante affiche le motif de suspension.
Le Command Center complet reste à développer.

## Données, récupération et compatibilité

- Rapport de calibration : schéma 2 conservé. Les observations moteur brutes
  ne sont stockées qu'une fois dans `motorTests` ; `drivetrain` devient un résumé
  dérivé explicite (`kind=derived-motor-summary`, schéma interne 1). Le lecteur
  existant reconstruit déjà les courbes depuis `motorTests`, y compris en
  0.18.80. Pas de perte des observations ni de conversion destructive.
- Chaque nouvelle enveloppe porte son propre schéma 1. Les anciens rapports
  restent lisibles et sont recontrôlés par les protections existantes.
- Les anciennes versions ignorent les champs supplémentaires ; une restauration
  du code n'efface pas les observations plus récentes.
- Aucune modification du JAR 0.2.3. Aucun JAR serveur remplacé automatiquement.
- Depuis 0.18.87, suivre le [retour compatible](COMPACT-SOURCE-0.18.87.md) :
  0.18.86 avec correctif Cobalt est le retour qualifié. Les instructions anciennes
  suivantes concernent les versions précédant le format 2.
- Retour au code 0.18.80 : exécuter l'installateur épinglé au commit
  `7947f2cf7ff31803691d4a6d735e1e31b9ecd947`, après arrêt explicite du pilotage.
  Les profils, rapports, configurations et fichiers personnels sont conservés.

  ```lua
  wget run https://raw.githubusercontent.com/commandant-x/MintCraftOS/7947f2cf7ff31803691d4a6d735e1e31b9ecd947/install.lua
  ```
- Les reprises après écriture interrompue restent transactionnelles. Aucun
  effacement de données utilisateur n'est utilisé pour gagner de la place.

## Travaux restants, dans l'ordre demandé

**Lot A encore en cours** : inventaire générique complet des commandes et
provenances ; caractérisation réellement six axes avec bruit et couplages ;
calibration/allocation des propulseurs et multirotors détectés ; identification
des gains par architecture ; extension de la surveillance partielle RPM/surcharge aux architectures
réellement identifiées ; dérive, oscillation et évolution du freinage ; diagnostic
borné de l'absence de progrès d'un sweep ; interface des capacités courantes.
Ne pas activer ces modes sur les seules matrices algébriques de test.

**Lot B** : invalidation indépendante des sous-modèles et identification passive
supplémentaire. L'adaptation de masse 0.18.80 demeure une compensation locale.

**Lot C** : capteur de terrain chargé et dimensionné, stockage Atlas borné,
incertitude/âge, volume du véhicule, obstacles et planificateur 3D. Les contrats
`system.ascendancy` restent la base ; aucun terrain n'est inventé.

**Lot D** : machine de mission explicite, décollage et atterrissage qualifiés
avec mesures de surface, dégagement, descente et contact. Atterrissage manuel
jusque-là. Ne jamais conclure à un contact depuis la seule altitude.

**Lot E** : itinéraires persistants, pause/reprise, retour, rapports et supervision
par service avec option détachée explicite. Ne pas changer l'arrêt à fermeture
sans option et contrôles du propriétaire.

## Validation

Les tests matriciels couvrent neuf configurations simplifiées : ballon,
dirigeable, propulseurs, quadrirotor, asymétrie, couplage de centre de masse,
moteur perdu, changement d'échelle de réponse et capteur absent. Ce sont des
fixtures algébriques, **pas neuf simulateurs de vol complets**.

Le simulateur de service existant vérifie effectivement : 60 modes, matrice
avant/lacet, enveloppe issue d'arrêts observés, guidage, freinage, réutilisation,
jam moteur avec RX encore valides, clutches désengagés et chauffe maintenue,
masse variable, STOP, permissions, identité, données périmées et stockage.

Aucun serveur Minecraft de qualification n'est attaché : essais en jeu **non
effectués**. Protocole requis sur installation de test : calibration en zone
libre, arrêt manuel/F10, trajet court avec freinage, virage, suspension d'une
commande moteur sans couper le retour du brûleur, changement de masse, puis
vérification des retours et du maintien vertical. Les autres architectures
attendent leur caractérisation réelle. Aucune autonomie complète annoncée.

### Résultats de l'incrément A.1

- 161 suites Lua réussies sur sources et runtime compressé.
- Compilation : 357 fichiers source et 164 fichiers du runtime compressé.
- Rapport moteur simulé encodé : 30 845 octets après déduplication
  (54 291 avant) ; reconstruction et réutilisation testées.
- Installation : 906 359 octets avec 100 000 octets de fichiers utilisateur.
- Pic du scénario mise à jour/checkpoint/retour : 971 787 octets.
- Mise à jour depuis 0.18.80, sauvegardes existantes conservées et récupération
  après interruption : tests réussis. Pas de validation Minecraft en jeu.

### Fondation A.2 livrée en 0.18.82 ; prochaine étape A.3

Poursuivre le lot A, pas les lots terrain/atterrissage : relier les observations
six axes à des expériences de commandes vérifiées et aux incertitudes mesurées.
Le repère angulaire natif n'est plus déclaré monde sans preuve ; A.2 dérive les
rotations depuis `sabled.pose()` et publie les frames/horodatages explicites.
Vérifier leurs conventions dans les API réelles avant transformation vers le corps.
Ne pas réécrire l'allocateur différentiel ni les calibrations déjà qualifiées.
La matrice générique seule ne donne pas le droit d'actuer un multirotor.

### Fondation A.3 livrée en 0.18.83

Les essais différentiels existants collectent maintenant les réponses six axes
soustraites au neutre, leur dispersion et leur point de fonctionnement. Le
collecteur impose les intervalles entièrement postérieurs aux confirmations RX ;
les essais trop courts ou perturbés par la chauffe restent insuffisants. Il
conserve quatre groupes au maximum et distingue les observations historiques des
recontrôles frais. Aucun contrôle six axes n'est activé depuis ces diagnostics.

Prochaine étape du lot A : utiliser des expériences physiquement attribuables
pour identifier les couplages et leurs limites, puis qualifier les architectures
réellement exposées. La surveillance de progrès du sweep et l'interface des
capacités restent également à compléter.

Résultats A.3 : 164 suites Lua réussies sur sources et runtime compressé ;
compilation de 363 fichiers source et 167 fichiers du runtime. Rapport moteur
simulé encodé : 35 518 octets. Installation : 921 886 octets avec 100 000 octets
de données utilisateur ; pic mise à jour/checkpoint/retour : 988 727 octets.
Mise à jour sans nouvel historique depuis 0.18.82 : pic 960 363 octets, données et
anciens checkpoints conservés par défaut, récupération après interruption vérifiée.
Aucun essai Minecraft réalisé.

### Diagnostic A.4 livré en 0.18.84

Le sweep explique les attentes de récepteurs, montée/descente continue,
oscillation et absence de progrès clair sur huit fenêtres disjointes. Ce
[diagnostic borné](ASCENDANCY-A4-SWEEP-PROGRESS.md) ne remplace aucun critère
physique et ne rajoute aucun délai maximal ou abandon automatique. STOP/F10
reste l'abandon explicite. La calibration et l'allocation génériques du lot A
restent à développer ; les observations A.3 ne les certifient pas.

Résultats A.4 : 165 suites réussies sur sources et runtime compressé ; compilation
365 fichiers source / 168 fichiers runtime. Installation : 924 817 octets avec
100 000 octets de fichiers utilisateur ; pic mise à jour/checkpoint/retour :
991 733 octets. Mise à jour depuis 0.18.83 sans nouvel historique : pic 934 508
octets ; anciens checkpoints préservés par défaut et interruptions récupérées.
Aucun essai Minecraft effectué.

### Interface A.5 livrée en 0.18.85

La [vue native État](ASCENDANCY-A5-CAPABILITIES.md), dans le cockpit existant,
rassemble les capacités actuelles, essais, adaptation, attente du sweep,
observations moteur et limites. Les états périmés ne certifient aucune commande.
Aucun onglet global ou second contrôleur n'est ajouté ; STOP reste immédiat.
La calibration/allocation universelle et la surveillance mécanique attribuable
aux chaînes réelles restent à développer. Ce n'est pas la livraison du lot A complet.

Résultats A.5 : 166 suites réussies sur sources et runtime compressé ; compilation
367 fichiers source / 169 fichiers runtime. Installation : 929 725 octets avec
100 000 octets de données personnelles ; pic mise à jour/checkpoint/retour :
996 712 octets. Mise à jour depuis 0.18.84 sans nouvel historique : pic 941 415
octets, données et anciens checkpoints conservés par défaut, interruption récupérée.
Le scénario avec conservation de rollback approche la limite : toute extension
suivante devra revalider ce budget, sans supprimer les données utilisateur.
Aucun essai Minecraft effectué.

### Diagnostic A.6 livré en 0.18.86

Le [graphe cinétique borné](ASCENDANCY-A6-KINETIC-GRAPH.md) expose les arêtes
Create réelles, RPM signés/théoriques, état du clutch et surcharge dans le
catalogue autorisé. Les chemins absents/cycliques/tronqués sont explicites.
Aucune fréquence n'est liée à un mécanisme par proximité seule ; ce diagnostic
ne coupe aucune banque depuis une association non qualifiée. La corrélation des
états physiques pendant les essais existants reste nécessaire avant de brancher
ces informations au superviseur. Aucun changement du JAR 0.2.3.

Résultats A.6 : 167 suites réussies sur sources et runtime compressé ; compilation
368 fichiers source / 169 fichiers runtime. Installation : 930 937 octets avec
100 000 octets de données personnelles ; pic mise à jour/checkpoint/retour :
997 924 octets. Mise à jour depuis 0.18.85 sans nouvel historique : pic 940 858
octets, anciens checkpoints conservés par défaut et interruptions récupérées.
Installateur reproductible octet pour octet. Aucun essai Minecraft effectué.
La marge du scénario avec rollback conservé est désormais de 2 076 octets :
optimiser/revalider le stockage avant une extension substantielle supplémentaire.

### Stockage préalable A.7 — 0.18.87

Le [format de source 2](COMPACT-SOURCE-0.18.87.md) et la préparation transactionnelle
par fichier récupèrent de la place pour poursuivre le lot A. Aucune ligne de code
ou donnée n'est retirée : égalité exacte des sources décompressées, autorisation
avant préparation, conservation des champs personnalisés et du décodeur nécessaire
aux applications préservées après rollback. Les checkpoints existants ne sont
pas purgés implicitement. L'outil de retour compatible restaure le code 0.18.86
sans devoir recopier tous les wrappers. Le lot A universel reste à implémenter.

Résultats A.7 : 171 suites réussies sur sources et runtime compressé ; compilation
376 fichiers source / 171 fichiers runtime. Cobalt 0.9.9 compile aussi les wrappers
et décompresse/compare/compile les 170 modules installés. Cette vérification a
révélé les chaînes longues imbriquées du premier alphabet et les 69 captures de
la boucle de vol : corrections avant publication, alphabet final 118 symboles,
variables privées regroupées, boucle à 55 captures. Aucun nouveau contrôleur.
La comparaison avec le simulateur 0.18.86 sous Lua 5.2 conserve exactement les
3 674 commandes Link, y compris calibration, moteurs, adaptation de masse et STOP.

Installation : 888 594 octets avec 100 000 octets personnels, soit 42 343 octets
récupérés par rapport à 0.18.86. Pic mise à jour/checkpoint/retour : 952 544 octets.
Migration réelle 0.18.86 → 0.18.87 : 150 sources réencodées ; 888 082 octets après
migration ; pic migration/retour compatible/remise à niveau : 980 856 octets.
Le retour 0.18.86 conserve son correctif Cobalt épinglé ; ses 168 sources sont
également compilées par Cobalt. Les autres fichiers et paramètres restent ceux
du retour demandé. Le client ancien limité au callback final refuse proprement
si l'espace manque ; la préparation autorisée puis le même callback passent
avec un pic de 982 392 octets. Le client Update 0.18.86 possède le callback requis.
Coupures : 55 points de préparation, 72 points de politique de stockage, plus
les scénarios existants de sauvegarde/transaction/installateur et reprise.
Checkpoints et données conservés par défaut. Aucun essai Minecraft effectué ;
Bridge 0.2.3 inchangé.

Reprendre ensuite le lot A : qualifier les liaisons de commande avec les états
mécaniques observés pendant les essais existants, avant toute attribution d'une
panne RPM à une banque ; continuer la caractérisation/allocation réellement
multi-axes sans activer une architecture sur de simples diagnostics.
