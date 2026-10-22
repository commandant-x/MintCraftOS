# Autopilot Ascendancy — état du développement

## Périmètre et référence inspectée

Le document utilisateur « PROJECT AUTOPILOT ASCENDANCY » demande de commencer
par le lot A et d'étendre l'existant. `origin/main` a été récupéré et comparé :
référence 0.18.80, commit `7947f2cf7ff31803691d4a6d735e1e31b9ecd947`.
La version 0.18.81 livre un premier incrément **partiel** du lot A. Elle ne livre
ni Autonomy 2.0 complète ni l'ensemble du lot A.

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
des gains par architecture ; surveillance RPM/surcharge reliée aux seules
chaînes concernées ; dérive, oscillation et évolution du freinage ; diagnostic
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

### Prochaine étape de travail — A.2

Poursuivre le lot A, pas les lots terrain/atterrissage : inventorier les commandes
et leur provenance puis produire des observations six axes correctement horodatées.
Le cache Sable expose déjà `linearVelocity` en m/s et `angularVelocity` en rad/s
avec fraîcheur et repère monde ; `sabled.pose()` fournit la pose/identité.
Vérifier leurs conventions dans les API réelles avant transformation vers le corps.
Ne pas réécrire l'allocateur différentiel ni les calibrations déjà qualifiées.
La matrice générique seule ne donne pas le droit d'actuer un multirotor.
