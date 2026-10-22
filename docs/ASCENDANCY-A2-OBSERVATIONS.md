# Ascendancy A.2 — observations et inventaire, 0.18.82

Cet incrément reste **partiel au sein du lot A**. Il prépare la caractérisation
universelle ; il ne réalise ni nouvelles impulsions, ni identification de gains,
ni allocation six axes. Les contrôleurs altitude et différentiel restent les
seuls parcours automatiquement qualifiés. Référence inspectée : 0.18.81,
commit `76cf5785750ad6e96bf0739547b49dda55c73576`.

## Repère angulaire vérifié, sans supposition d'API

Le source CC:Sable 1.3.4 disponible dans l'environnement renvoie les champs
`latestLinearVelocity` et `latestAngularVelocity` de Sable. L'inspection du JAR
Sable 1.21.1/2.0.6 disponible montre que `SubLevelPhysicsSystem` calcule la rotation
relative par `current.difference(last).conjugate()` puis multiplie par 20 pour
le temps de tick. Ce vecteur n'est pas une preuve d'un repère monde commun à
chaque version. La mesure native reste disponible en rad/s, avec `frame=unknown`
et un motif explicite. Aucun serveur utilisateur n'a été modifié pour cette
inspection.

Les dérivées utilisées ici viennent de `sabled.pose()` : UUID, pose monde et
horodatages déjà acquis. La normalisation réutilise les formats de quaternion
existants, plats, tableaux et `{a,v}`. La rotation `current * conjugate(previous)`
donne l'axe de rotation dans le monde. Le signe équivalent d'un quaternion est
traité. Une rotation proche de 180° entre observations est déclarée ambiguë.
Les tours multiples entre deux poses restent non observables : aucun certificat
ne repose sur le seul fait que cette observation est disponible.

## Estimation bornée

`system.navigation.state_estimator` conserve une pose précédente et ses dérivées,
pas un historique croissant. Trois poses consécutives permettent d'obtenir
accélération linéaire et accélération angulaire. Les vitesses portent le milieu
de leur intervalle ; les accélérations utilisent l'écart entre ces milieux,
y compris si les échantillons ne sont pas uniformément espacés.

Données : position en blocs, vitesse en blocs/s, accélération en blocs/s²,
rotation en rad/s et rad/s². Les vecteurs monde sont transformés vers les axes
orthonormés de l'orientation du dernier échantillon ; `orientationAt` reste
explicite. Ce repère n'est pas une conversion d'échelle vers les blocs du plot.
La réponse nommée fournit X=droite, Y=vertical, Z=avant et les rotations positives
main droite autour de X/Y/Z, converties en degrés/s² pour le diagnostic matriciel.
Ce ne sont pas les angles d'Euler d'Avionics et leurs signes ne sont pas supposés.

Les timestamps sont les débuts de lecture fournis par le cache Sable, pas un
horodatage natif exact de l'intégrateur physique. La précision physique de ces
dérivées reste à qualifier ; aucun niveau de confiance statistique n'est inventé.
Les données indiquent l'intervalle source, l'instant dérivé, l'expiration, la
méthode et l'identifiant d'horloge de `system.ascendancy.contracts`. UUID différent,
repère inconnu, timestamp futur/périmé/régressif, intervalle inférieur à 0,02 s
ou supérieur à 0,5 s réinitialisent l'historique. Une publication répétée ne
renouvelle pas une observation. Un quaternion absent laisse une observation
partielle, sans axes de corps inventés. Aucun dépassement numérique n'est publié
comme une réponse finie.

`flightd.step()` alimente cet estimateur depuis le cache de pose existant, sans
appel supplémentaire à un périphérique. `flightd.kinematics()` et le champ
`flightd.status().kinematics` lisent uniquement le résultat en cache. Une
observation six axes n'étend pas `flightd.status().authority` : l'autorité
avant/lacet reste celle de la calibration réelle de l'incrément A.1.

## Catalogue de commandes

`system.navigation.command_catalogue` décrit les canaux déjà configurés et les
six signaux des deux chaînes moteur existantes. Chaque ligne fournit son ID
logique stable, backend/endpoint, portée de véhicule déclarée, fréquences,
limites entières, neutre, politique de secours, rôle, mix déclaré et retour RX
lorsque le cache expose ce retour. Les transmissions/inverseurs indiquent bien
que le secours conserve leur valeur observée et désengage les clutches.
Un signal accepté ou un mix configuré ne devient pas une preuve de réponse.

Le catalogue expose les brûleurs, actionneurs et mécanismes réellement inventoriés,
avec les liens `sourceId`, RPM et états disponibles. Il n'associe pas une hélice
au brûleur voisin et ne crée aucune commande pour un bloc inconnu. Un servo
sans API/mapping pris en charge reste sans commande identifiée. L'affectation
manuelle existante est conservée ; aucune fréquence n'est essayée pour la deviner.
Les chevauchements de fréquences entre commandes sont signalés comme ambigus.

Budgets : 38 commandes (32 canaux + 6 signaux moteurs), 64 équipements affichés,
256 clés de fréquence publiées et 64 IDs de brûleurs partagés. Les totaux et
marqueurs de troncature restent explicites. Les fréquences complètes sont utilisées
pour vérifier le retour du groupe, même lorsque la liste publiée est partielle.
Le catalogue reste une description de mappings, avec `independentAxes={}` :
les autorisations physiques courantes demeurent exclusivement dans `flightd`.

`flightd` reconstruit ce cache au plus une fois par seconde. Les récepteurs sont
indexés pour éviter de rescanner tous les liens pour chaque fréquence. Les
fonctions de dessin ne font aucune acquisition. `flightd.commands(actor)` vérifie
le processus Navigation et les permissions de lecture avant de copier les données.
Le redémarrage et la persistance d'un changement de configuration invalident le
cache ; une lecture expirée n'expose pas un ancien retour comme disponible.

## Identifiants et STOP

L'inventaire a révélé que l'ancien secours reconnaissait les canaux internes
moteur au simple préfixe de leur nom. Un canal utilisateur nommé `drive-*` pouvait
ainsi être ignoré. Le secours utilise maintenant l'appartenance effective aux
six signaux moteur : un canal utilisateur reçoit sa valeur de secours, quel que
soit son nom. Les six IDs moteur réservés ne peuvent pas être réutilisés par un
canal configuré lorsque la transmission correspondante est active. Le contrôle
a lieu à la configuration, à la validation et avant un sweep. Aucun ID utilisateur
n'est renommé, aucun profil n'est migré ou effacé. Le test de service vérifie les
sorties effectives de deux brûleurs d'un canal personnalisé après STOP.

## Sources ASCENDANCY

Deux adaptateurs en lecture seule s'ajoutent aux contrats existants :

- `navigation.kinematics` : observations six axes dérivées, repère monde et
  sous-repère corps explicitement décrit dans le payload ;
- `navigation.commands` : mappings et inventaire en cache, pas certificat de vol.

Les deux exigent `navigation.assist` **et** `sable.read` avant de charger/lire
le service. Les descriptions d'adaptateur publient ces prérequis. Une autorisation
insuffisante, une donnée absente ou périmée ne produit aucun payload inventé.
Ni adaptateur ni catalogue ne commence une acquisition, une calibration ou une
commande physique.

## Données et retour arrière

Aucun nouveau fichier utilisateur, modèle, calibration ou sortie persistante.
Les caches sont de schéma 1, éphémères ; aucun réarmement après redémarrage.
Vehicle Bridge reste 0.2.3, Java inchangé. Retour au code 0.18.81, après arrêt
explicite du pilote :

```lua
wget run https://raw.githubusercontent.com/commandant-x/MintCraftOS/76cf5785750ad6e96bf0739547b49dda55c73576/install.lua
```

Les profils, calibrations et fichiers personnels restent conservés.

## Qualification et suite

Tests : quaternions orientés, rotation combinée, signes équivalents, intervalle
ambigu, dérivées non uniformes, unités et timestamps, capteurs absents, UUID changé,
expiration, overflow, historique borné, refus des permissions avant accès aux
caches, groupes RX, politiques moteur, fréquences partagées, troncature et budget
d'interchange. Le simulateur de service confirme que les observations arrivent
sans qualifier de nouveaux axes et que les commandes restent privées.

Aucun essai Minecraft réalisé. Prochaine étape A.3 : collecteur d'expériences
avec provenance de commande, bruit, couplages et conditions d'essai vérifiées,
puis calibration et allocation des architectures réellement identifiées.
Ne pas utiliser les accélérations instantanées pour certifier un moteur isolé
sans distinguer les autres commandes, la gravité et les perturbations.

### Résultats mesurés de l'incrément

- 163 suites Lua réussies sur les sources et le runtime compressé.
- Compilation : 361 fichiers source ; 166 fichiers du runtime compressé.
- Installation : 916 460 octets avec 100 000 octets de fichiers utilisateur.
- Pic du scénario mise à jour/checkpoint/retour : 982 893 octets.
- Mise à jour depuis 0.18.81 : données et anciens checkpoints conservés,
  récupération après interruption testée.
- Artefact Sable inspecté : `sable-neoforge-1.21.1-2.0.6.jar`, SHA-256
  `9c199157843bf953a47dff625fc5bb41c01a90538d35ad18e6996bbcb8a617c2`.
  C'est l'artefact disponible dans l'environnement de développement ; aucune
  affirmation sur le binaire installé sur un serveur utilisateur non inspecté.
