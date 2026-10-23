# A.9 — caractérisation des sorties et maintien local mesuré — 0.18.89

Cet incrément poursuit le lot A. Il ne termine ni Ascendancy ni les lots A–E.
Les voies existantes ballon/brûleurs et moteurs différentiels restent utilisées
pour leurs configurations. `flightd` reste l'unique auteur des commandes.

## Utilisation

Pour une configuration sans groupe de brûleurs ni drivetrain différentiel :

1. Affecter une seule fois les commandes physiques connues dans Actuators. Chaque
   sortie doit avoir ses bornes, son neutre et son secours. Les fréquences partagées
   entre sorties logiques sont refusées. Aucune fréquence inconnue n'est essayée.
2. Établir et confirmer un véritable neutre de sustentation stable. Le programme
   ne déduit pas un régime de sustentation à partir du nombre de rotors. Un neutre
   instable empêche le prochain essai et son motif reste visible.
3. Confirmer une fois la reprise manuelle physique et le comportement du secours
   après son essai réel. Le retour RX seul ne démontre aucun interrupteur matériel.
   L'activation automatique refuse ces preuves absentes ; la caractérisation seule
   n'accorde jamais le droit de voler. Dans Calibration, « Mesurer les sorties » caractérise seulement les sorties
   affectées et revient au secours configuré. « Activer autopilot » sur cette même
   configuration ajoute les essais physiques en boucle fermée puis le maintien
   local, après confirmation d'une zone libre. STOP/F10 interrompt la procédure.
4. Après qualification verticale, Control permet de saisir une altitude dans la
   plage monde réellement parcourue. Les commandes vitesse/cap et les missions
   génériques ne sont pas encore disponibles. Les routes différentielles existantes
   restent disponibles avec leurs protections et leur confirmation de trajet libre.
5. « Enregistrer les mesures » conserve un rapport transactionnel borné dans
   `/system/config/navigation-response.cfg`. Il contient horloge de session,
   unités, observations isolées, masse, affectations, empreinte si disponible,
   domaines et essais de retour. Ce fichier ne restaure jamais de sorties.
   Un manque de place laisse les données en RAM ; aucune donnée personnelle
   n'est supprimée. Un trim de masse ou une dégradation n'est pas exporté comme
   nouvelle calibration. La réutilisation automatique de ce format reste à faire.

## Preuves physiques

Chaque impulsion autorisée est bornée à neutre ±1 et au maximum deux secondes.
Le passage au prochain essai exige le retour à un neutre effectivement stationnaire,
pas l'expiration d'un délai. Les moyennes et dispersions des six dérivées de pose
utilisent des intervalles entièrement postérieurs à l'ACK et au retour physique.
Les modèles refusent les repères, identités, horloges, unités et signes incohérents.
L'allocation couplée distingue le rang d'une matrice de la faisabilité réelle dans
les bornes des sorties. Les sorties de vol restent dans les niveaux testés.

Les axes candidats doivent ensuite effectuer des déplacements opposés et un retour,
avec mouvement observé, vitesse résiduelle et dispersion qualifiées. Les consignes
et erreurs sont en repère monde ; l'allocation tourne les colonnes réelles du corps.
La quantification analogique sur 16 niveaux conserve l'erreur dans l'espace des
réponses couplées. Un modèle algébrique seul n'arme jamais le véhicule.

Pour l'inclinaison, les essais d'attitude déjà autorisés alimentent un estimateur
passif : direction de poussée, accélération et vitesse réelles, séparation de la
traînée et du biais. Aucune constante de gravité n'est inventée dans le contrôleur.
La boucle horizontale respecte le temps de stabilisation mesuré de l'attitude ;
les mouvements X/Z doivent passer une seconde qualification distincte. Un modèle
inobservable ou contradictoire laisse ces axes indisponibles.

Le diagnostic utilise au plus 32 observations pour reconnaître une absence de
convergence ou des oscillations non amorties ; attendre ne crée aucun certificat.
Une perte horizontale mesurée suspend ces commandes et conserve le vertical
seulement s'il est qualifié. Une variation de masse seule déclenche un trim borné
au même objectif Y, sans balayage en mission. L'épuisement réellement observé de
l'autorité verticale/d'attitude reste une cause de secours configuré.

## Vehicle Bridge 0.3.0

Le nouveau JAR ajoute une lecture rapide de 1 à 64 nœuds déjà inventoriés du parent,
au plus une fois par deux ticks par API et 256 nœuds par tick au total. La lecture
est effectuée sur le thread serveur, dans les chunks déjà chargés, sans écriture,
assemblage ou chargement de chunks. Elle ne rafraîchit ni la coque ni la masse.
Le cache Lua impose identité, provenance, ordre des ticks et bail privé de session ;
STOP libère le bail. L'absence de cette méthode sur les anciens JAR reste explicite
et conserve la voie d'inventaire lente, sans inventer de retour frais.

Voir le README de l'addon pour installation manuelle, empreinte SHA-256 et retour
à 0.2.3. L'installateur Lua ne remplace aucun mod du serveur.

## Qualification et limites

Les tests comprennent neuf plantes simplifiées, l'estimateur de production,
les dérivées de quaternion, allocation/quantification, retours réels de commande
simulés, pertes de propriétaire/capteur/RX/UUID, STOP, fermeture et variation de
masse. Le test multirotor part explicitement d'un modèle de rotors déjà calibré :
il prouve le contrôle et la découverte passive de l'inclinaison dans cette plante,
pas une calibration universelle de rotors inconnus en jeu. Le besoin d'un neutre
stable n'est pas contourné. Aucun essai Minecraft n'a été effectué ici.

À terminer : réutilisation indépendante des modèles, commissioning plus large,
terrain réel/planification 3D, phases de vol et atterrissage qualifiés, missions
persistantes/détachées et command center complet. Le sélecteur Atlas reste sans
terrain : aucune garantie d'évitement ou d'atterrissage automatique.

## Retour arrière

Le code 0.18.88 est conservé sur GitHub au commit
`ceef6a8bd4b64a9b2dc8ef95f1c41b74cc52f344`. Après STOP, utiliser le chargeur de retour compatible :
`wget run https://raw.githubusercontent.com/commandant-x/MintCraftOS/main/tools/rollback-compatible.lua ceef6a8bd4b64a9b2dc8ef95f1c41b74cc52f344`.
Il restaure les corps applicatifs de 0.18.88 en conservant les lecteurs compacts
compatibles et le moteur transactionnel. L’ancien installateur brut ne suffit pas
à préserver les représentations récentes sur un disque de 1 Mo.
Les configurations et le nouveau rapport ne sont pas effacés ni interprétés par
l'ancien contrôleur. Le stockage d'un historique local n'est pas requis.

## Stockage et compression sans perte

Le format 3 utilise DEFLATE brut, l'alphabet ASCII existant, une longueur bornée
et Adler-32. Les anciens formats restent lisibles. Le décodeur est autonome et
vérifié avec des vecteurs zlib indépendants : blocs stockés, Huffman fixe/dynamique,
blocs multiples, recouvrements, Unicode, binaire, troncatures et expansions refusées.
Les sources Git, commentaires et octets décodés restent identiques.

L'installateur autorise la préparation avant toute écriture, installe les lecteurs
compatibles transactionnellement, puis ne recompresse que des corps rigoureusement
équivalents. Un retour arrière garde leur représentation plus petite. La première
installation déplace les fichiers validés de la zone de préparation plutôt que
créer une seconde copie du même contenu. Les interruptions de bootstrap,
représentation et écriture applicative ont des tests de récupération séparés.

Disque compté conservativement à au moins 512 octets par fichier/dossier, avec
100 000 octets de données utilisateur : installation 729 605 octets ; petite mise
à jour/checkpoint/retour 758 065 au pic ; parcours 0.18.88 → 0.18.89 → retour
compatible → réinstallation 908 567 au pic. Une mise à jour avec checkpoint retenu
explicite a atteint 942 651 octets au pic. La politique normale reste sans historique
permanent. Les checkpoints déjà présents ne sont supprimés que par une demande de
purge explicite ; la compression n'autorise aucune suppression de données privées.

## Protocole Minecraft à exécuter

Essais non réalisés dans cet environnement. Utiliser une construction de test et
une zone réellement dégagée ; conserver la commande manuelle et STOP accessibles.

- Vérifier UUID, pose monde, unités et fraîcheur, puis les RX et neutres réellement
  affectés. Un neutre instable doit expliquer le refus sans sonder d'autres canaux.
- Mesurer les sorties. Observer chaque impulsion, le retour neutre et le secours
  effectivement reçu. Sauvegarder le rapport ; une mesure seule ne doit pas armer.
- Lancer la qualification automatique depuis un neutre stable. Observer les deux
  sens et le retour de chaque axe proposé. Pour l'inclinaison, exiger des essais
  X/Z séparés ; un axe absent doit rester indisponible.
- Demander une petite variation d'altitude dans le domaine mesuré, revenir, vérifier
  le freinage et le maintien. Les objectifs hors domaine doivent être refusés.
- Sur la construction d'essai, modifier légèrement la masse : conserver l'objectif Y,
  suspendre l'horizontal et constater un trim sans nouvelles impulsions de mesure.
  Le rapport ne doit pas appeler cette compensation une recalibration complète.
- Tester STOP en impulsion, retour et maintien ; retirer un RX/capteur ou révoquer
  le propriétaire. Vérifier les sorties de secours réellement appliquées et aucune
  nouvelle impulsion après STOP. Vérifier aussi la fermeture de Navigation.
- Redémarrer : aucune sortie ne doit être réarmée par le rapport archivé. Vérifier
  la lecture des fichiers personnels après mise à jour et retour compatible.

Les essais de terrain, décollage, mission et atterrissage appartiennent aux lots
suivants. Cet incrément ne présente aucun de ces modes comme qualifié.

Qualification automatisée : 181 suites Lua sources et 181 suites installées
compactées passent ; les gardes physiques finales ont aussi leur test intégré
rejoué sur les deux représentations. Cobalt compile les 181 chunks installés
et le probe décode/compare/compile les 180 corps applicatifs et tous les vecteurs
DEFLATE. La compilation et les tests Java 0.3.0 passent contre Sable 2.0.6.
