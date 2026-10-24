# Quad natif Sputnik 0.1.11 — contrôleur expérimental

Cette version ajoute réellement un nœud qui émet vers **quatre fréquences Link**.
Le Kalman et la stabilisation sont intégrés à ce nœud, pas simplement présents
dans le SDK. Le mode physique automatique ci-dessous calcule le modèle à partir de la
masse, de la pression et de la géométrie confirmée. Le mode manuel historique
reste disponible. Les tests sont des simulations ; aucun vol Minecraft n'a été réalisé.

## Mode physique automatique — ne plus remplir les sept coefficients

Pour quatre petits rotors **fixes, verticaux, identiques et poussant vers le haut**,
un quad symétrique avec centre de masse au centre, et les réglages Overworld
par défaut de Sable/Aeronautics : cocher le mode « Calcul physique » dans
`quad-controller`. **Laisser vides les quatre anciennes lignes** de coefficients.

Renseigner les paramètres géométriques simples :

- `Demi-largeur` : distance horizontale du centre de masse à une hélice vers la
  gauche/droite. Si l'écart gauche-droite est 6 blocs, entrer 3.
- `Demi-longueur` : distance vers l'avant/arrière, même principe.
- `Hauteur rotors moins hauteur Sputnik` : différence verticale, en blocs,
  entre le centre des blocs hélices et celui du Sputnik.

Les distances concernent le repère local du véhicule, avec avant=+Z et droite=+X.
Ne pas supposer qu'un centre de masse décalé coïncide avec le centre de la croix.
Le mode ne convient pas aux rotors inclinables ni à une répartition asymétrique.
Sputnik ne fournit ni positions des hélices ni centre de masse : ces données ne
peuvent pas être détectées automatiquement avec l'API stock actuelle.

Les champs préremplis correspondent aux valeurs auditées : **256 RPM d'entrée**,
coefficient de poussée 1, coefficient d'écoulement 0,1, gravité 11. Confirmer
l'absence de modifications serveur/datapack avant d'activer ce modèle.

Le calcul automatique utilise :

1. La **masse actuelle et les inerties diagonales X/Z**, lues via les API serveur
   réelles `getShipMass` et `getInertiaTensor`, sans inventer un tenseur complet.
2. La pression au niveau de chaque rotor, avec la courbe cubique Hermite utilisée
   par Sable, y compris son raccordement vers pression nulle à Y=320.
3. La transmission `RPM = RPM_entrée × (15 − signal) / 16` : **à signal 0,
   256 RPM d'entrée donnent 240 RPM sur l'arbre**, et 15 donne zéro. Ce n'est pas
   la relation supposée 256 × (15−signal)/15.
4. La poussée statique des petits rotors `F = coefficient × RPM × pression`,
   réduite par l'écoulement axial lorsque le rotor monte dans l'air :
   `F = coefficient × RPM × pression × clamp(1 − vitesse_axiale/(coefficient_air × RPM), 0, 1)`.
   À l'arrêt, la poussée est nulle. Il ne s'agit pas d'une loi inventée en RPM².
5. Le poids `masse × gravité` et les moments `r × F`, puis les inerties pour
   produire automatiquement la matrice verticale/tangage/roulis et l'équilibre.

La commande d'équilibre n'est **pas figée** : masse, inertie, altitude, vitesse
axiale, inclinaison et pression aux rotors actualisent le modèle à chaque nouvelle
observation. Le Kalman et les corrections ferment ensuite la boucle. Des niveaux
voisins sont alternés si l'équilibre demandé tombe entre deux valeurs entières.
Une intégrale corrige les écarts locaux restants, sans sweep lors d'un changement
de masse. Un centre de masse déplacé ou un changement d'orientation des rotors
sort néanmoins des hypothèses du modèle symétrique.

Sur Display Link, `MC_FORCE` donne poussée maximale totale disponible, poids et
pression. `MC_ROTOR_1` à `MC_ROTOR_4` donnent la poussée maximale de chaque rotor,
les RPM à signal zéro et le signal d'équilibre calculé. Les valeurs sont celles
du modèle par défaut, **pas des capteurs de poussée ou des ACK des transmissions**.
Si la pression ou la réserve de poussée ne permet plus de soutenir le poids,
le calcul le signale et refuse le modèle au lieu de promettre un vol impossible.
Le repli constant ne peut pas compenser une absence physique de sustentation.

Les formules et courbes ont été vérifiées dans les JAR actuels : Aeronautics et
Simulated 1.3.2, Sable 2.0.6 pour Minecraft 1.21.1. Les empreintes et hypothèses sont
incluses dans `profiles/aeronautics-1.3.2-defaults.json`. La courbe Lua est comparée
à 421 valeurs produites par **la vraie classe Java de Sable**. Les essais de vol
restent des simulations, avec interpolation de régime de 0,15 par tick ; aucune
validation Minecraft en jeu n'est revendiquée. La physique serveur personnalisée
n'est pas lisible par Sputnik stock : ce mode ne doit pas l'assimiler aux défauts.

## Mise à jour depuis 0.1.7

Mettre le levier à zéro et conserver une copie du graphe actuel. Pour éviter
le mélange d'anciens widgets avec les nouveaux, supprimer les trois anciens
nœuds du quad puis importer le nouveau `mintcraft-quad-flight.clipboard.txt`.
Reconfigurer les mêmes fréquences. Ne pas garder deux contrôleurs qui émettent
vers les mêmes hélices. Le fichier sauvegardé et l'historique Git permettent de
revenir à la version précédente.

## Import et branchement

Sauvegarder le graphe actuel. Importer `mintcraft-quad-flight.clipboard.txt` dans
le fond vide de l'éditeur Sputnik puis F pour cadrer les six nœuds. Sauvegarder,
fermer et rouvrir avant de configurer les widgets. Ce graphe **ajoute** un lecteur
de levier, un clavier et un contrôleur : ne pas conserver un autre émetteur qui
commande les mêmes rotors. L'ancien graphe Venator n'est pas modifié.

- `quad-enable` : fréquence dédiée à un levier physique ; arrêt d'autorisation à 0.
- `quad-keyboard` : les six fréquences du Linked Typewriter, décrites dans README.
- `quad-controller` : **quatre paires de sélecteurs d'objets Link**, dans l'ordre
  avant gauche, avant droite, arrière gauche, arrière droite. Ce sont les
  fréquences des récepteurs qui commandent vos quatre transmissions.

Les seize fils logiques sont déjà raccordés : levier vers les deux autorisations,
puis trois axes du clavier et son indicateur de validité vers le contrôleur.
Deux liaisons de description des fréquences permettent de refuser les collisions
entre le clavier, le levier et les quatre sorties.
Aucun `vehicle-mixer` ou ancien `drive-mixer` n'est nécessaire sur cette chaîne.
La flèche avant choisie pour les noms des rotors est **le +Z local de Sputnik** ;
la droite est +X. Un bloc tourné ou un repère différent exige de mesurer les
réponses dans le même repère que la télémétrie, pas de recopier les noms d'une photo.

## Mode manuel historique : modèle mesuré des quatre transmissions

Sous chaque paire de fréquence, le champ attend sept nombres séparés par des
virgules :

`trim,min,max,dY,dPitch,dRoll,repli`

| Valeur | Signification |
| --- | --- |
| trim | Niveau entier 0–15 de cette transmission au stationnaire vérifié |
| min,max | Domaine local **mesuré** de signaux, avec min < trim < max |
| dY | Variation d'accélération verticale en bloc/s² par niveau redstone |
| dPitch,dRoll | Variations d'accélération angulaire, degrés/s² par niveau |
| repli | Signal entier vérifié pour reprise physique en cas de défaut |

Les coefficients sont signés : une transmission où augmenter le signal réduit
la poussée doit avoir une réponse verticale négative. Le logiciel ne suppose
ni une courbe linéaire 0–15 entière ni une poussée maximum à 15. Les quatre
réponses doivent permettre trois axes indépendants : vertical, tangage, roulis.
Les modèles sans rang suffisant sont refusés. Le lacet reste libre.

Exemple **de simulation uniquement**, à ne pas copier comme calibration réelle :
`8,4,12,0.4,-8,8,8`. Aucune de ces valeurs n'est présumée valable sur votre quad.
Pour établir les coefficients, partir d'un stationnaire maintenu par des
commandes physiques indépendantes ; comparer l'accélération au neutre à celle
obtenue par une petite variation d'un seul rotor, les autres restant identiques.
Réitérer des deux côtés et sur plusieurs observations. Si la réponse varie trop
ou si le montage ne peut pas être testé ainsi, ne pas cocher la confirmation.
Ce mode manuel ne réalise pas de calibration automatique ; le mode physique
ci-dessus remplace ces coefficients uniquement pour les montages et réglages
qu'il prend en charge.

Le repli est envoyé sur les anciennes fréquences figées si une configuration
change pendant le vol. Il n'est jamais inventé comme 0 ou 15. Un signal constant
ne garantit pas le stationnaire : prévoir une priorité physique indépendante
pour reprendre les transmissions. Le levier d'autorisation déclenche ce repli,
ce n'est pas un arrêt mécanique universel ni une procédure d'atterrissage.

## Estimation et stabilisation fournies

- Cinq filtres Kalman position/vitesse à deux états : X, Y, Z, pitch et roll.
  Modèle à vitesse constante, bruit d'accélération de processus et bruit de
  position ; covariance mise à jour sous forme Joseph. Les valeurs de bruit
  affichées sont des paramètres initiaux de prototype, à ajuster aux mesures.
- Horloge serveur en ticks ; intervalles non positifs ou > 0,5 s refusés.
- Capture de l'altitude au démarrage ; Space/Shift déplacent sa consigne,
  relâcher maintient la dernière consigne. Maintien X/Z au relâchement.
- Conversion des consignes relatives au véhicule vers les axes monde au yaw
  mesuré ; vitesse → inclinaison → accélérations de tangage/roulis amorties.
- Compensation de la composante verticale de poussée pendant l'inclinaison.
- Allocation des trois accélérations dans la matrice locale 3×4 mesurée,
  saturation commune dans le domaine et signaux entiers 0–15 avec diffusion
  d'erreur temporelle. Une saturation prolongée réduit l'autorité disponible.
- Intégrale verticale bornée avec anti-windup ; changement de masse sans
  nouveau sweep, conservation de la cible Y tant que l'autorité le permet.

Ce n'est pas un EKF de navigation six axes : pas de fusion GPS/IMU indépendantes,
pas d'identité Sable vérifiable, pas de contrôle de yaw, de terrain ou de cap.
L'orientation Euler et le modèle sont réservés au vol proche de l'horizontale.
Les gains sont ceux d'un prototype testé sur des plantes simplifiées ; ils ne
sont pas identifiés automatiquement dans votre monde. La gravité est 11 dans
le mode physique par défaut ; le mode manuel historique conserve 9,81.
Les cas asymétriques, délais Link, dommages ou collisions peuvent dépasser le
modèle. `Flight qualified` reste à zéro même lorsque `Active` vaut 1.

## Activation

1. Autorisation à zéro, configurer les dix fréquences clavier/rotors et celle du
   levier, toutes distinctes. Le graphe vérifie les collisions entre ces onze paires. Personne d'autre
   ne doit émettre sur ces canaux ; les autres graphes/joueurs restent invisibles.
2. Vérifier le retour à zéro des touches et le modèle/repli avec reprise physique.
   Cocher les deux confirmations correspondantes. Le contrôleur refuse un
   démarrage si pitch ou roll dépassent 10 degrés.
3. Laisser quelques mises à jour serveur à zéro, touches relâchées, puis activer
   le levier. Le contrôleur attend que le clavier soit valide et au neutre.
4. Lire `MC_KEYS_RAW`, `MC_KEYS`, `MC_QUAD` avec Display Link / Display Board.
   L'interface client peut ne pas afficher l'état serveur en temps réel.
5. Commencer par le maintien vertical, puis de petites commandes. Les paramètres
   vitesse horizontale, vitesse verticale et inclinaison maximale sont visibles.
   Ce sont des enveloppes du prototype, pas une certification de vol.

Une faute est mémorisée jusqu'à une nouvelle séquence autorisation zéro puis
activation au neutre. Si le clavier devient invalide pendant un vol actif, le
contrôleur demande freinage/maintien au lieu de couper la sustentation. Une
vraie perte de contexte, de pose, une discontinuité, une inclinaison >25 degrés,
un changement de fréquence ou une erreur d'émission déclenche le repli configuré.
Le succès d'un appel Link n'est pas un accusé de réception physique ; l'absence
d'identité/source fraîche vérifiable interdit de présenter ce système comme
un autopilote qualifié. Les essais de simulation ne remplacent pas les mesures.

## Lire le refus exact avec la 0.1.10

Le graphe comporte un `String Display` natif, nommé **MintCraft quad-status**,
relié à `Status` du contrôleur. Choisir ce nœud dans le Display Link, plutôt
qu'une clé MC_QUAD absente de la liste client. La carte `displayBridge` du mod
n'est pas incluse dans la synchronisation de son bloc. Le texte du panneau
physique donne le diagnostic de l'exécution serveur ; l'étiquette visible dans
l'éditeur peut seulement représenter sa configuration côté client.

Les anciens messages génériques sont remplacés par des motifs précis et leurs
valeurs quand elles sont utiles. Une confirmation affichée cochée côté client
mais reçue décochée au serveur produit `CONFIRM` ; une liaison de description
manquante produit `ENABLE_BIND` ou `KEY_COUNT: 0/6`, sans supposer que les
fréquences radio elles-mêmes sont défaillantes. Les défauts de masse restent
visibles sur `Status`, y compris lorsque le contrôleur ne peut pas s'armer.

## Diagnostic de masse et commandes sur un graphe existant

Le complément `mintcraft-flight-audit.clipboard.txt` ajoute une télémétrie en
lecture seule. Ses six entrées et le choix Display Link sont détaillés dans
README, section 0.1.11. Il permet d'observer les mesures serveur et la consigne
qui atteint le contrôleur sans remplacer un graphe déjà configuré. Son fichier
Lua n'appelle aucun émetteur ni API d'actionnement. Les nouveaux graphes complets
le raccordent automatiquement.

L'état « actif » signifie que le code de boucle s'exécute. Il ne prouve pas que
les quatre rotors correspondent au repérage +X/+Z ni que le centre de masse réel
est centré. La masse et les inerties sont lues, mais l'API stock n'expose pas
la position du centre de masse ; une erreur de cette hypothèse demande de
revoir l'allocation/identification, pas de prétendre que le Kalman la corrige.
