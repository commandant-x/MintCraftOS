# Quad natif Sputnik 0.1.7 — contrôleur expérimental

Cette version ajoute réellement un nœud qui émet vers **quatre fréquences Link**.
Le Kalman et la stabilisation sont intégrés à ce nœud, pas simplement présents
dans le SDK. Le modèle physique de votre quad doit être fourni et vérifié avant
activation. Les tests sont des simulations ; aucun vol Minecraft n'a été réalisé.

## Import et branchement

Sauvegarder le graphe actuel. Importer `mintcraft-quad-flight.clipboard.txt` dans
le fond vide de l'éditeur Sputnik puis F pour cadrer les trois nœuds. Sauvegarder,
fermer et rouvrir avant de configurer les widgets. Ce graphe **ajoute** un lecteur
de levier, un clavier et un contrôleur : ne pas conserver un autre émetteur qui
commande les mêmes rotors. L'ancien graphe Venator n'est pas modifié.

- `quad-enable` : fréquence dédiée à un levier physique ; arrêt d'autorisation à 0.
- `quad-keyboard` : les six fréquences du Linked Typewriter, décrites dans README.
- `quad-controller` : **quatre paires de sélecteurs d'objets Link**, dans l'ordre
  avant gauche, avant droite, arrière gauche, arrière droite. Ce sont les
  fréquences des récepteurs qui commandent vos quatre transmissions.

Les huit fils logiques sont déjà raccordés : levier vers les deux autorisations,
puis trois axes du clavier et son indicateur de validité vers le contrôleur.
Deux liaisons de description des fréquences permettent de refuser les collisions
entre le clavier, le levier et les quatre sorties.
Aucun `vehicle-mixer` ou ancien `drive-mixer` n'est nécessaire sur cette chaîne.
La flèche avant choisie pour les noms des rotors est **le +Z local de Sputnik** ;
la droite est +X. Un bloc tourné ou un repère différent exige de mesurer les
réponses dans le même repère que la télémétrie, pas de recopier les noms d'une photo.

## Modèle mesuré des quatre transmissions

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
**La calibration automatique de ces coefficients n'est pas fournie.**

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
Les gains et la gravité nominale 9,81 sont ceux d'un prototype testé sur une
plante simplifiée ; ils ne sont pas identifiés automatiquement dans votre monde.
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
