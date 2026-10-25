# Quad natif Sputnik 0.1.18 — contrôleur expérimental

Cette version ajoute réellement un nœud qui émet vers **quatre fréquences Link**.
Le Kalman et la stabilisation sont intégrés à ce nœud, pas simplement présents
dans le SDK. Le mode physique automatique ci-dessous calcule le modèle à partir de la
masse, de la pression et de la géométrie confirmée. Le mode manuel historique
reste disponible. Les tests sont des simulations ; aucun vol Minecraft n'a été réalisé.

## Quatre hélices fixes : courber la trajectoire — 0.1.18

La case **Q/D: virage de trajectoire (nez non pilote)** est activée par défaut.
W/S accélèrent/freinent sur le cap de trajectoire demandé. Q/D courbent ce cap
progressivement en demandant une accélération centripète, et non une diagonale
fixe. Le cap demandé est conservé lorsque Q/D sont relâchées ; il ne revient
pas automatiquement au cap initial ou au cap du nez. Les phases de freinage et de maintien de la 0.1.17
restent utilisées lorsque toutes les commandes de déplacement sont relâchées.

Ce mode ne commande **pas le lacet du corps**. Dans les versions auditées,
les petites hélices fixes appliquent une force au point de montage, sans
couple de réaction autour de leur axe. Quatre poussées verticales offrent
portance, tangage et roulis ; elles ne donnent pas un quatrième canal de lacet
indépendant. Le nez peut dériver par couplage physique sans être piloté. Les
sorties `Track heading` et `Body yaw controlled=0` distinguent ce fait ; le
statut affiche `TRAJ` (consigne de trajectoire) et `NEZ` (angle mesuré).
Q/D seules à l'arrêt ne font donc pas pivoter le véhicule.

La courbure dépend de la poussée horizontale disponible et de la vitesse :
à vitesse élevée, les virages sont plus larges. La vitesse de rotation de la
trajectoire est bornée à 30°/s aux faibles vitesses pour garder la demande
compatible avec la réponse de l'attitude. Cela n'ajoute pas de plafond de
vitesse horizontale. Le cap demandé ne s'éloigne pas sans limite d'une
trajectoire qui ne peut pas suivre ; la réserve de sustentation reste active.

Décocher la case, autorisation coupée, conserve l'ancien déplacement latéral
Q/D. Les fonctions du SDK gardent aussi leur comportement classique sauf si
`config.steering=true` est fourni explicitement.

Après validation du clavier et des six fréquences, le contrôleur lit ses
récepteurs directement au tick courant. L'armement, le neutre initial, les
collisions de fréquences et la validité du clavier restent requis. Une lecture
invalide revient au freinage/maintien. Cela supprime une étape du graphe,
nominalement 50 ms à 20 TPS ; la montée en régime des hélices ne change pas.
La case **Consignes clavier Link directes** est activée par défaut. La décocher,
autorisation coupée, conserve la consommation des entrées du graphe pour un
autre fournisseur de consignes. Le statut indique `LINK` ou `GRAPH`.

Voir le [rapport de trajectoire](https://github.com/commandant-x/MintCraftOS/blob/main/platforms/sputnik/reports/course-0.1.18/README.md)
pour les courbes, la variation du cap de déplacement et le cap réel du nez.
Ce compromis ne transforme pas le montage en drone FPV avec lacet indépendant.

## Déplacement à inclinaison maintenue — 0.1.17

Les touches horizontales ne poursuivent plus une vitesse de 2 m/s. Tant que
W/S/Q/D reste maintenue, `TRAVEL` demande une inclinaison constante dans la
direction choisie, normalisée pour les diagonales. Le quad continue à accélérer
jusqu'à son équilibre physique ; il n'existe plus de plafond de vitesse
horizontale fixé par le champ `speed`. Le champ **inclinaison déplacement**
détermine cette inclinaison : 8° par défaut, réglable jusqu'à 15° dans
l'enveloppe de ce contrôleur. Ce changement conserve les gains d'attitude de
la 0.1.16, qui fonctionnaient sur le véhicule du joueur.

Au relâchement, `BRAKE` freine la vitesse avec une anticipation de 0,4 s du
retard des hélices. Une fois le quad lent et près du niveau, `HOLD` capture
le point d'arrêt. Le pilote ne ramène plus le véhicule vers le point où la
touche a été relâchée, ce qui provoquait un aller-retour indésirable. Le champ
anciennement appelé « vitesse » ne règle maintenant que la vitesse de retour
du maintien de position. Space/Shift continuent de déplacer la consigne
d'altitude ; aucune attente chronométrée ne déclenche les phases de freinage
ou de maintien.

L'inclinaison est réduite si la poussée maximale prédite ne peut pas soutenir
le poids avec une réserve de 10 %. Cette réserve permet encore de corriger
l'attitude malgré le retard des hélices et les variations d'écoulement. Le
statut affiche alors `LIFT_LIMIT` : c'est une contrainte de sustentation, pas
un plafond arbitraire en m/s. Une machine très proche de sa portance maximale
peut rester à plat sans pouvoir accélérer horizontalement.

Le statut affiche aussi `TRAVEL`, `BRAKE` ou `HOLD`, ainsi que `Vh`.
L'audit lit indépendamment `getVelocity` et expose la vitesse horizontale
native. La sortie du contrôleur expose sa vitesse horizontale filtrée.

Le [rapport déplacement](https://github.com/commandant-x/MintCraftOS/blob/main/platforms/sputnik/reports/travel-0.1.17/README.md)
mesure l'inclinaison pendant les appuis prolongés, la vitesse atteinte,
le retour arrière au freinage, les changements de masse et un essai sans
traînée jusqu'à la limite de sustentation. Ces vitesses sont celles d'un banc
paramétré, pas une vitesse maximale garantie pour le serveur du joueur.

## Réponse et résonance — 0.1.16

La version précédente pouvait encore entrer en oscillation avec de faibles
inerties. Son inversion de l'écoulement axial dû à la rotation cherchait à
annuler un amortissement aérodynamique utile, mais les hélices répondaient avec
retard. Le contrôleur conserve désormais cet amortissement passif. La plante
de test continue bien à appliquer l'écoulement complet, rotation comprise :
la difficulté physique n'a pas été retirée du banc.

Le retour d'attitude utilise l'angle mesuré récent, la vitesse angulaire filtrée
et une accélération angulaire filtrée séparément. Les gains proportionnels du
mode physique dépendent de la pression, des bras de levier, du coefficient
d'écoulement et des inerties réellement lues, avec des bornes 4..40. Les retours
de vitesse et d'accélération ont des gains 4,5 et 0,6. La translation utilise
des gains position/vitesse de 0,3/0,9 pour une réponse plus rapide.

Le contrôle reste à la cadence du bloc Sputnik, nominalement 20 Hz : aucune
attente artificielle n'est ajoutée entre les corrections. Les champs et les
fréquences restent les mêmes. Le panneau d'audit expose maintenant `Ixyz` et
les trois inerties natives, pour rapprocher le prochain banc du véhicule réel.

Le banc ajoute des inversions toutes les 0,5/1 s, des efforts périodiques, du
bruit d'attitude et des inerties divisées jusqu'à huit. Une réussite exige aussi
une inclinaison RMS < 2° et une vitesse RMS < 0,2 m/s sur les dix dernières
secondes ; atteindre la cible sur le seul dernier échantillon ne suffit plus.
La suite standard exécute trois de ces tests de résonance avec assertions.

Les résultats complets, temps de réponse et limites figurent dans le
[rapport de résonance](https://github.com/commandant-x/MintCraftOS/blob/main/platforms/sputnik/reports/resonance-0.1.16/README.md).
Les gains sont éprouvés sur un banc paramétré ; cela ne certifie pas un vol réel.

## Stabilisation éprouvée sur un banc 3D indépendant — 0.1.15

Un nouveau banc exécute les véritables nœuds Lua livrés dans le LuaJ de
Cosmonautics, face à une plante rigide indépendante à quaternion et forces
appliquées aux quatre hélices. Le modèle continue après un défaut du pilote.
Il inclut la quantification des transmissions, la montée en régime à 0,15 par
tick, le délai radio et des variations de masse, d'inertie et de centre de masse.

Ce banc a révélé des oscillations masquées par les anciens essais simplifiés.
Le taux angulaire utilisé pour amortir l'attitude est désormais calculé sur
les angles mesurés récents, puis filtré avec une constante de 50 ms. Ce n'est
pas un gyroscope inventé : ce sont des différences d'angles Euler près du niveau.
Le Kalman reste utilisé pour la position, la vitesse et l'attitude filtrée.
La correction d'attitude utilise des gains P=2,5 et D=3 ; la boucle de translation
est ralentie (gain position 0,25 et vitesse 0,6) pour ne plus combattre la
réponse retardée des hélices. Ces gains sont testés sur ce banc, pas calibrés
sur le véhicule réel du joueur.

Avec la masse et les dimensions déclarées par le joueur (**32 kg, demi-largeur
3 m, demi-longueur 5 m**), sur 20 cas de référence identiques la 0.1.14 en
réussissait 12 ; la correction en réussit 19. Le cas avec des inerties quatre
fois plus faibles que les valeurs supposées conserve une oscillation excessive.
Les six cas supplémentaires de mauvaise mécanique, fréquences concurrentes,
rotor affaibli ou centre de masse mal renseigné restent des échecs ; ils ne sont
pas cachés. Les inerties réelles ne sont pas connues. Une chute déjà rapide peut
perdre plusieurs mètres avant de récupérer, même quand le critère final de
stationnaire est atteint.

Voir le [rapport numérique](https://github.com/commandant-x/MintCraftOS/blob/main/platforms/sputnik/reports/digital-twin/README.md) pour les résultats,
traces, hypothèses, critères et commande de reproduction. Ce banc n'est pas
une réplique mesurée du véhicule et ne lance pas le solveur Minecraft/Sable.
Il ne délivre aucune qualification de vol.

## Autorisation et puissance séparées — 0.1.14

Le levier sur sa fréquence dédiée fournit uniquement une **autorisation** :
signal physique 0 = OFF ; tout entier 1 à 15 = ON. Le lecteur fournit alors
`Enable=1`, jamais la puissance analogique du levier. Cette valeur ne sert ni
de consigne moteur, ni de multiplicateur des commandes des hélices.

Après un OFF réel et une activation à plat avec configuration valide, le
contrôleur capture la position et l'altitude puis calcule les quatre niveaux
de transmission indépendamment. Il démarre ce maintien même si `Commands valid`
vaut 0 : un clavier pas encore prêt ne bloque plus la stabilisation. Les
fréquences clavier doivent néanmoins être configurées et raccordées pour
vérifier leur séparation des sorties moteur. Un clavier valide avec une touche
maintenue doit être relâché avant le démarrage. Pendant le maintien, des
commandes invalides sont ignorées ; des commandes valides déplacent les consignes.

Sur un quad symétrique réellement à plat, une chute verticale appelle une
augmentation collective de la poussée : les quatre signaux baissent ensemble
dans le sens réducteur de ces transmissions. Le test couvre ce cas et compare
les traces moteur obtenues pour chacune des quinze puissances d'autorisation.
Il ne prouve ni le câblage réel des quatre fréquences, ni le centrage du véhicule.

Le levier ne doit alimenter ni une transmission directement, ni un émetteur
sur une fréquence moteur : un autre émetteur à 15 y imposerait l'arrêt.
L'état OFF conserve le comportement de repli existant ; il ne constitue pas
une procédure automatique d'atterrissage.

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
3. La propagation effective de la transmission : **signal 0 = passage direct**,
   donc 256 RPM d'entrée donnent 256 RPM. Pour les signaux 1 à 15,
   `RPM = RPM_entrée × (15 − signal) / 16` dans le sens réducteur. Le cas spécial
   de `propagateRotationTo` prime sur `getRotationModifier`. Il n'y a pas d'état
   entier à 240 RPM : un mélange temporel entre 0 et 1 peut en approcher la moyenne.
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

## Un arrêt ne revient plus silencieusement à BASELINE

La 0.1.12 garde le premier défaut sur `Status` et `Last fault`, avec les angles et
la masse du dernier incident. Le message `BASELINE` désigne uniquement un
démarrage sans état neutre préalable ; il ne remplace plus un défaut en vol.
Lire le panneau après l'incident avant de réarmer. Une autorisation éteinte avec
une configuration valide pendant deux nouvelles observations acquitte ensuite
la faute. La correction ne supprime pas les conditions d'arrêt ni ne certifie
la stabilisation du montage.

## Sens mécanique de la transmission — 0.1.13

Le modèle suppose **moteur sur l'arbre principal de la transmission**, puis
**hélice entraînée par son engrenage supplémentaire** (rapport extérieur 1:1).
Deux appareils sur le même arbre principal ne forment pas cette chaîne de
réduction. En entraînant l'engrenage supplémentaire et en sortant par l'arbre,
la transmission applique l'inverse du rapport : elle multiplie la vitesse.

À 256 RPM d'entrée, le sens multiplicateur demande environ 292,6 RPM au signal 1.
Si la limite Create est 256, `AnalogTransmissionBlockEntity.propagateRotationTo`
marque alors la transmission comme `oversaturated` et interrompt la propagation.
Le tooltip des lunettes d'ingénieur peut indiquer une vitesse excessive. Une
hélice arrêtée dans ce cas ne peut pas être remise en marche par un réglage PID.
Le blocage exact doit être confirmé sur le montage : une commande radio réussie
ne prouve ni l'alimentation mécanique ni l'absence de surcharge.

Avec le quad posé et le pilote désactivé, vérifier la vitesse réelle sur la
chaîne réductrice avant d'armer :

| Signal | RPM attendus pour 256 RPM à l'entrée |
| --- | --- |
| 0 | 256 (bypass) |
| 1 | 224 |
| 7 | 128 |
| 14 | 16 |
| 15 | 0 |

La version précédente de ce guide annonçait à tort 240 RPM au signal zéro :
le calcul ignorait le bypass de propagation. Le modèle, son inverse et les tests
sont corrigés. L'interpolation 0..1 est un mélange des deux commandes matérielles
entières 0 et 1, jamais l'envoi d'une valeur redstone fractionnaire.

## Reprise sans redémarrage et commandes moteur visibles

Le levier à zéro acquitte désormais un défaut après deux nouvelles observations
serveur même si le modèle doit être réparé. Les anciennes fréquences continuent
de recevoir le repli figé ; elles ne sont pas abandonnées à un zéro radio qui
ferait repartir les hélices à pleine vitesse. Une configuration invalide reste
interdite à l'armement. Une fois le modèle valide et le quad redressé, l'état
`LEVEL_WAIT` attend un départ à +/-10 degrés sans créer une nouvelle faute ni
exiger un redémarrage du script. La limite de fonctionnement n'est pas retirée.

Le clavier peut également attendre le relâchement des touches après un vrai
passage du levier à zéro, sans rester bloqué après une commutation rapide. Il
ne s'arme jamais sur une touche tenue ou au démarrage avec autorisation haute.

Pendant la boucle, le panneau `quad-status` affiche `RUN m=... K=... F=... L=...
Y=... R=a/b/c/d h=actuelle>cible`. `R` représente les quatre **signaux demandés**,
pas une mesure des RPM ou un accusé de réception des hélices. Ces valeurs
séparent une réception clavier correcte d'une transmission qui ne tourne pas.

### Un levier allumé n'est pas une puissance de 1

Un levier allumé émet **15/15**, pas 1/15 : il est normal qu'il arrête l'hélice.
Ce test seul ne prouve pas que la transmission est branchée en multiplicateur.
Vérifier une puissance analogique réellement égale à 1 avant cette conclusion.

Create retient la plus forte valeur des émetteurs Link d'une fréquence. Un
émetteur d'essai resté à 15 peut donc l'emporter sur une commande du pilote
à 3 ou 4. Une source redstone directement adjacente à la transmission peut
également imposer 15 via `getBestNeighborSignal`. Désactiver les commandes
d'essai des moteurs avant le vol, conserver l'autorisation sur sa fréquence
séparée et éviter tout autre auteur sur les canaux des rotors.

Le contrôleur affiche `RADIO_n: demande X reseau Y` si sa lecture du réseau
indique une valeur supérieure à sa demande. C'est un indice d'émetteur concurrent,
**pas un capteur de RPM ni une preuve de réception du Link physique**. Une source
directement posée à côté de la transmission ne peut pas être détectée ainsi.
Une lecture nulle/manquante ne prouve pas que la transmission reçoit le signal.
