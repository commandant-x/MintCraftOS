> 0.3.2 : allocation quad à priorité collective, modèles séparés par rotor et compensation du retard ; voir [QUAD-FPV.md](QUAD-FPV.md). Les contrôleurs standard restent inchangés. Les réussites et échecs synthétiques sont publiés séparément de la validation Minecraft.

# Autopilote Sputnik 0.2.2 — un TXT par architecture

Choisir **un seul** graphe :

| Véhicule | TXT à copier intégralement | Groupes | Nœuds / connexions |
| --- | --- | ---: | ---: |
| Quad | [mintcraft-quad-autopilot.clipboard.txt](dist/mintcraft-quad-autopilot.clipboard.txt) | 4 sustentations | 10 / 29 |
| Ballon | [mintcraft-balloon-autopilot.clipboard.txt](dist/mintcraft-balloon-autopilot.clipboard.txt) | 1 sustentation, 1 propulsion, 2 gouvernes | 10 / 29 |
| Venator | [mintcraft-venator-autopilot.clipboard.txt](dist/mintcraft-venator-autopilot.clipboard.txt) | 4 sustentations, 2 banques de propulsion | 12 / 35 |
| Hélicoptère | [mintcraft-helicopter-autopilot.clipboard.txt](dist/mintcraft-helicopter-autopilot.clipboard.txt) | 1 sustentation, 1 propulsion, 2 commandes de lacet | 10 / 29 |

L’architecture et les modèles de groupe sont préchargés. Les groupes restent désactivés et les fréquences vierges : configurer le montage réel avant activation. Chaque variante conserve exactement le contrôleur de vol de la 0.2.0. Les nouveaux formulaires simples gardent la puissance, le type, les voiles et les positions ; la direction verticale est automatique sur les sustentations. Les autres propriétés restent accessibles dans le champ Expert ou par import complet MCV1. Les limites de calibration et de vol restent celles documentées dans [AUTOPILOT.md](AUTOPILOT.md).

La carte et le second afficheur ne sont plus inclus. L’agrégateur n’affiche que les entrées des quatre ou six groupes, au lieu de 32. Cela réduit les formulaires, les connexions et le rendu de l’éditeur ; ce n’est pas une mesure de FPS ni une réduction annoncée du coût du calcul physique. Le graphe [universel avancé](dist/mintcraft-autopilot.clipboard.txt) reste disponible pour les montages personnalisés, avec huit formulaires et sa carte.

## Installation du nouveau graphe

1. Télécharger le TXT de votre architecture dans le tableau ci-dessus et copier **tout son contenu**, sans guillemets ni espaces ajoutés.
2. Au sol, couper mécaniquement les moteurs indépendamment de Sputnik. Exporter votre ancien montage, puis retirer son contrôleur pour éviter deux émetteurs concurrents.
3. Dans le fond vide de l’éditeur Sputnik, coller avec **Ctrl+V**, puis sauvegarder. Le collage ajoute tout le graphe ; ne pas coller le TXT dans l’éditeur Lua d’un nœud.
4. Ne pas conserver l’ancien graphe en parallèle. Suivre [Montage → essais → pilotage](AUTOPILOT.md). Renseigner les fréquences et les caractéristiques propres à chaque hélice. Le nouveau pilote exige un passage physique Enable OFF avant activation.

Le [ZIP courant](dist/mintcraft-sputnik-0.2.2.zip) contient aussi les sources, tests et rapports. Aucun programme CC ni accès aux fichiers du serveur n’est nécessaire. Les modèles restent déclarés ; le pilote ne scanne pas les voiles ou la coque.

Le contrôleur continue côté serveur après fermeture de l’éditeur. Une mise à jour ne doit pas s’effectuer en vol : l’expiration Link peut ramener un signal à zéro, qui signifie plein régime pour certaines transmissions.

## Piloter sans choisir un numéro de mode

Saisir la hauteur puis cliquer **Tenir cette altitude**. **Maintenir ici** capture la hauteur courante ; **Suivre vitesse et cap** utilise les deux autres champs. Les boutons **Tester le montage**, **Pause essais** et **Reprendre essais** gardent les tests accessibles. Sauvegarder puis fermer l’éditeur transmet la demande ; le panneau montre la révision acceptée. Les routes, points et commandes spécialisées restent sous **Navigation et commandes avancées**.

## Réglages avancés conservés

Un formulaire moteur ne montre plus de champ Direction à confondre avec Position. Dans **Expert**, on peut par exemple déclarer `gain=20;neutral=8` pour une réponse locale connue, ou `dx=0;dy=1;dz=0;alpha=0.2;run=15` pour personnaliser direction, rampe et polarité du clutch. Les propriétés déjà présentes dans les champs simples se modifient dans ces champs, pas en double dans Expert. Toute propriété du contrat MCV1 reste représentable et l’import restitue les propriétés supplémentaires dans Expert. Ces réglages restent déclarés, sans scan ou preuve physique automatique.

L’agrégateur simple lit toujours les formulaires : il n’a plus de case d’import global qui pourrait les masquer avec deux champs vides. Pour un montage hybride ou pour les formulaires complets, le graphe universel avancé reste disponible.

## Garder les fréquences déjà renseignées

Avant de retirer l’ancien graphe, au sol et désarmé : dans chaque formulaire moteur, cliquer **Exporter ce groupe** et conserver le texte MCV1. Dans le nouveau formulaire correspondant, coller ce texte dans **Copie / import du groupe complet**, puis cliquer **Charger ce groupe depuis le champ**. Les fréquences et propriétés avancées du groupe sont conservées. Les fréquences du levier et du clavier ainsi que les réglages généraux sont à reporter séparément. Vérifier le montage et repasser physiquement par OFF avant activation.

## Carte facultative

Importer uniquement [mintcraft-local-map.clipboard.txt](dist/mintcraft-local-map.clipboard.txt), puis relier les quatre sorties `Geometry`, `Route`, `Position`, `Trace` du contrôleur aux entrées du même nom de la carte. Aucun deuxième contrôleur n’est nécessaire. Laisser la carte absente si l’éditeur ralentit.

## Résultats et limites

Voir les [tests des graphes séparés](reports/interface-0.2.2/README.md), le [banc numérique](reports/universal-0.2.0/README.md) et [les fonctions restant à terminer](IMPLEMENTATION-STATUS.md). Les simulations ne constituent pas une validation dans Minecraft. Les virages serrés du ballon et certains cas de faibles inerties restent expérimentaux.

<details>
<summary>Anciennes éditions 0.1.x et outils séparés — documentation historique</summary>

# MintCraft Sputnik 0.1.20

**0.1.20 : modèle des hélices modulaires Propeller Bearing.**
Nombre de blocs de voile indépendant par rotor, quatre champs et quatre entrées
de graphe ; poussée, airflow, trim et gains utilisent les coefficients des
Propeller Bearings. Pour quatre hélices de 12 voiles : saisir 12/12/12/12 et
activer le mode modulaire dans `quad-controller`.
Voir [le branchement et les limites](QUAD-FLIGHT.md#hélices-modulaires--0120).

**0.1.19 : sélecteur d’architecture enregistré dans le graphe.**
Quad, ballon, Venator et hélicoptère sont proposés. **Seul le quad possède
actuellement un contrôleur de vol natif opérationnel** ; les autres choix
affichent leur câblage prévu et refusent le démarrage du contrôleur quad.
Un changement en vol reste en attente jusqu’au levier OFF.
Voir [le sélecteur](QUAD-FLIGHT.md#sélecteur-darchitecture--0119).

**0.1.18 : Q/D courbent progressivement la trajectoire avec quatre hélices fixes.**
Le nez reste sans commande de lacet. Une case conserve le mode latéral classique.
Les consignes Link validées sont lues au tick courant pour éviter un étage de
latence du graphe. [Rapport et limites](https://github.com/commandant-x/MintCraftOS/blob/main/platforms/sputnik/reports/course-0.1.18/README.md).

**0.1.17 : appui maintenu = inclinaison maintenue, sans plafond de 2 m/s.**
Le quad accélère pendant l'appui, freine au relâchement puis maintient le point
d'arrêt. L'inclinaison reste limitée par la poussée disponible pour tenir en l'air.
Voir [les essais de déplacement](https://github.com/commandant-x/MintCraftOS/blob/main/platforms/sputnik/reports/travel-0.1.17/README.md).

**0.1.16 : correction de la résonance et réponse plus rapide.** L'amortissement
aérodynamique est conservé et les gains d'attitude s'adaptent aux inerties lues.
Voir [les essais de résonance](https://github.com/commandant-x/MintCraftOS/blob/main/platforms/sputnik/reports/resonance-0.1.16/README.md).
L'audit `Ixyz` montre les trois inerties natives. Le fichier à importer reste
`mintcraft-quad-flight.clipboard.txt`.

**0.1.15 : amortissement d'attitude corrigé après essais 3D indépendants.**
Le banc numérique expose les réussites et les échecs restants ; voir
[le rapport](https://github.com/commandant-x/MintCraftOS/blob/main/platforms/sputnik/reports/digital-twin/README.md). Aucun vol réel n'est certifié.

**0.1.14 : autorisation binaire et maintien autonome au neutre.** Le levier
1..15 devient `Enable=1`, sans transmission de sa puissance aux moteurs.
La stabilisation peut démarrer sans clavier prêt ; les touches valides servent
à déplacer les consignes. Voir [QUAD-FLIGHT.md](QUAD-FLIGHT.md).

Édition autonome pour **Cosmonautics 26.08.307, Minecraft 1.21.1**. CC:Tweaked et
Vehicle Bridge ne sont pas nécessaires. La version de votre serveur reste à
confirmer. Les versions anciennes de Cosmonautics peuvent utiliser un autre
éditeur et un format de graphe incompatible.

## Téléversement sans accès aux fichiers du serveur

1. Télécharger `dist/mintcraft-sputnik-0.2.2.zip` sur votre ordinateur personnel
   depuis GitHub et le décompresser.
2. Ouvrir le Sputnik en jeu. Sauvegarder son graphe existant : sélectionner les
   nœuds, copier et conserver ce presse-papiers dans un fichier personnel.
3. Dans la fenêtre **Flight Computer**, cliquer le fond vide du graphe puis
   fermer toute recherche ou champ de texte actif. Copier **tout le contenu** de `mintcraft-dashboard.clipboard.txt`, sans ajouter
   de guillemets, dans le presse-papiers de votre système.
4. Revenir dans l'éditeur de graphe Sputnik et faire **Ctrl+V**. Le collage ajoute
   un nœud Lua ; il ne supprime pas le graphe existant. Fermer/sauvegarder l'éditeur
   pour envoyer le graphe au serveur. Un ancien contrôleur continue d'exister : ne
   jamais conserver deux auteurs de commande sur le même canal.
5. Le tableau de bord démarre en lecture seule. Aucune chauffe, mise en marche de
   moteur ou transmission radio automatique.

Alternative : dans le fond du graphe, **Maj+A**, chercher **Lua Script**, puis
valider. **Double-cliquer dans le corps du nœud, sous son titre** pour ouvrir
l’éditeur Lua : le double-clic sur le titre sert à renommer. Dans la zone de code,
Ctrl+A puis Ctrl+V pour y coller `mintcraft-dashboard.lua`, appliquer puis sauvegarder le graphe.
Les fichiers `.clipboard.txt` sont du **Base64 de SNBT**, pas des JSON ni des URL.
Pas de `wget`, de shell CraftOS ni d'installateur CC dans Sputnik.

### Si le collage ne fait rien

Depuis la 0.1.1, la distribution corrige un retour à la ligne final dans les anciens fichiers Base64.
Sputnik le rejetait silencieusement. Utiliser les nouveaux fichiers sans espace,
sans guillemets et sans retour à la ligne ajouté. `mintcraft-import-test.clipboard.txt`
est un tout petit graphe de test : le nœud doit apparaître et afficher la sortie
`MintCraft test` égale à 1. Aucun actionneur n'est commandé.

Pour vérifier l'éditeur Lua sans importer de graphe, créer le nœud comme indiqué
ci-dessus et y saisir simplement `output("MintCraft test", 1)`, puis **Run (▶)**.
Fermer l'éditeur pour revenir au graphe et sauvegarder.


## Configurations Venator, airship et rotors

[Groupes de commande et limites physiques](VEHICLE-PROFILES.md) : le Venator décrit
possède deux banques arrière de deux moteurs et quatre pales indépendantes.
Le nœud `mintcraft-drive-mixer.lua` fournit les deux demandes de propulsion signées
et quatre demandes de sustentation normalisées, sans émettre de signal moteur.
Il gère marche arrière, pivot, rotation sur place et STOP horizontal laissant les
demandes de sustentation inchangées. Ces demandes **ne sont pas** des niveaux
redstone 0–15 : la table de transmission mesurée et les retours physiques restent
nécessaires avant tout actionnement. Le niveau 15 coupe les pales du Venator.

Le nouveau `mintcraft-vehicle-mixer.clipboard.txt` ajoute les profils ballon
(cinq fréquences) et quad sans propulsion (quatre sustentations). `Profile = 1`
choisit le ballon, `Profile = 2` le quad. Voir le guide des groupes pour les
entrées, la qualification nécessaire et la boucle d’attitude restant à intégrer.
Ce nœud produit uniquement des demandes et ne commande aucun Link.

## Câblage et tests automatiques des moteurs

Le [guide complet de câblage](WIRING-AND-TESTS.md) décrit le graphe à deux banques
préconnecté `mintcraft-two-bank-tests.clipboard.txt` : un levier physique, un
séquenceur, deux nœuds moteur. Il effectue les essais A/B séquentiellement après
configuration explicite et réception de la rotation réelle via Speedometer /
comparateur / Link. Les clutches utilisent une autorisation à état absent=arrêt.
Aucun canal de sustentation n'est commandé. Le résultat est une expérience de
propulsion en session, pas une qualification automatique d'autopilote.

## Contenu

- **Dashboard** natif : position/dimension, vitesse, attitude, masse serveur,
  horloge, inventaire à la demande et sorties numériques. La masse et l'horloge
  sont absentes de certaines vues client : cela est affiché, jamais remplacé par
  un faux certificat de télémétrie.
- **17 modules de calcul pour le développement, séparés du nœud** : géométrie, estimation de pose, autorité,
  identification/allocation six axes, contrôleur et qualification, inclinaison,
  convergence, balayage d'altitude, modèle altitude, guidage historique et contrats.
  Leurs sources sont incluses sans modifier leurs mathématiques. Leur présence
  n'active aucun pilote ; les preuves physiques requises restent obligatoires.
- **Link gateway**, optionnelle : deux sélecteurs d'items natifs pour la fréquence,
  entrées `Enable`, `STOP`, `Signal` et émission 0–15. Aucun moteur voisin n'est
  sélectionné automatiquement. Le signal radio/Link n'est pas un retour brûleur.
- **Numeric radio**, optionnelle : canal/code/valeur et émission sur un front
  manuel. Une réception est un cache sans horodatage ni authentification.

La bibliothèque de développement est séparée dans `sdk/mintcraft-library.lua`.
**Ne pas la coller en bloc dans Sputnik** : elle dépasse la limite NBT de
65 535 octets par chaîne. Elle sert aux tests et au développement de contrôleurs
ciblés ; le tableau de bord téléversable ne l'embarque plus et n'expose pas
`MintCraftSputnik.require`. Les modules restent conservés, sans activation de vol.

### Erreur réseau avec les anciennes versions

La 0.1.2 a corrigé le code de 108 508 octets embarqué dans le tableau de bord.
Le parseur de texte pouvait le lire, mais le paquet réseau échouait lors de
l'écriture NBT (`UTFDataFormatException`). Chaque nœud téléversable est maintenant
borné à 60 000 octets **UTF modifié Java**, et les tests écrivent réellement le NBT.
Le nouveau tableau de bord fait environ 4 Ko.

Si l'ancien nœud est encore affiché, ouvrir son éditeur et remplacer son code par
`output("Test", 1)`, exécuter puis sauvegarder. Ensuite remplacer ce petit code
par le nouveau `mintcraft-dashboard.lua`. Ne pas recoller les fichiers 0.1.0/0.1.1.
Si le client rouvre un ancien graphe surdimensionné, redémarrer d'abord Minecraft
pour vider son cache de graphes côté client ; aucun fichier de monde à supprimer.

## Passerelle Link : emploi explicite

Importer `mintcraft-link-gateway.clipboard.txt` uniquement si cette fonction est
voulue. Fermer/sauvegarder une première fois puis rouvrir le graphe pour que
les éléments natifs existent aussi côté serveur. Choisir les deux items de la fréquence connue. Relier `Enable` et `STOP`
à des commandes physiques indépendantes, et `Signal` à une source contrôlée.
`Enable` doit être vu à **0 après chargement pendant deux observations serveur distinctes**, puis passer à 1 ; un 1 déjà présent
au démarrage n'arme pas le nœud. STOP est prioritaire et impose un nouveau passage
à 0 de Enable. Un changement de fréquence demande zéro sur l'ancien canal et
retire l'armement. Une horloge en régression retire également l'armement.

**Zéro coupe une chauffe ; ce n'est pas un profil de secours en vol.** Prévoir
la reprise physique adaptée avant de relier la sortie à un brûleur. Le nœud ne
prétend pas confirmer la réception : l'API native d'émission ne retourne pas
d'acquittement. Les boutons locaux de l'éditeur ne sont pas utilisés comme arrêt
serveur. La fermeture de l'éditeur ne signifie pas arrêt d'un graphe serveur.
Le handler Link audité expire ses émetteurs virtuels après 10 ticks sans
rafraîchissement ; ce mécanisme du mod n'est pas une preuve de secours physique.

## Sécurité et limites

Les API publiques auditées ne donnent pas d'UUID Sable, de liste des brûleurs avec
association ballon, de géométrie complète ou de capteurs de collision. Les IDs
périphériques sont collectés au niveau de la dimension et ne prouvent pas
l'appartenance au vaisseau. Aucun modèle ne peut donc être automatiquement
requalifié sur cette seule base. `Flight qualified` reste 0.

Un mot de passe dans un nœud éditable ne protège pas le Sputnik contre un joueur
qui peut modifier le graphe. Protéger son accès avec les permissions/protections
réelles du serveur. Les liens et la radio natifs ne sont pas des canaux
authentifiés. Les accès Java/package ou fichiers non documentés du moteur Lua ne
sont pas utilisés. Browser, CraftTube et Store ne sont pas présentés comme
fonctionnels sans API HTTP officiellement exploitable.

**Tests automatisés et interpréteur réel du JAR : oui. Essai en jeu : non.**
Voir [COMPATIBILITY.md](COMPATIBILITY.md) pour la séparation entre fonctions
portées et fonctions qui nécessitent une intégration serveur supplémentaire.

## Retour arrière

Désactiver physiquement toute commande, retirer les nouveaux nœuds puis
sauvegarder. Restaurer au besoin le graphe personnel copié avant installation.
L'import n'a modifié aucun fichier CC, mod ou configuration serveur. Un contrôle
physique doit confirmer que les actionneurs ont repris l'état voulu.

## Reproduction

`python3 tools/build-sputnik.py` à la racine. Aucun téléchargement au build.
Les empreintes du code de calcul et des artefacts sont dans `dist/manifest.json`
et `dist/SHA256SUMS`. Le JAR audité est `cosmonautics-26.08.307.jar`, SHA-256
`3fd9dac868400905a55164d2c9d74abc2080ae3269ca51e54e1899874945973e`.

Validation reproductible :

```sh
python3 tools/test-sputnik.py --cosmonautics-jar /chemin/cosmonautics-26.08.307.jar --java-home /chemin/jdk-21
```

L'option `--minecraft-classpath` ajoute la validation du presse-papiers par le
vrai parseur SNBT Minecraft 1.21.1 mappé. Ces JAR ne sont pas redistribués dans
le paquet utilisateur. Les tests de physique restent des simulations.

## Clavier Linked Typewriter — 0.1.13

Importer `mintcraft-typewriter.clipboard.txt` dans le fond du graphe : ce nouveau
nœud est un récepteur, sans commande moteur. Sauvegarder, fermer puis rouvrir le
graphe avant de configurer ses widgets. Pour W, S, Q, D, Space et Shift, choisir
les deux mêmes objets que sur la fréquence correspondante du Linked Typewriter.
Les six paires doivent être distinctes et réservées au clavier, différentes des
fréquences des quatre transmissions. Le logiciel ne peut pas inventorier les
fréquences employées ailleurs par les joueurs.

Brancher une autorisation physique sur `Enable` (0 = désactivé, 1–15 = autorisé).
Le nœud `mintcraft-test-enable.clipboard.txt` peut lire une septième fréquence
Link dédiée à un levier et fournir ce signal. Cette autorisation n'est pas une
coupure matérielle des pales. Ne pas la partager avec les essais de propulsion.
Avec un Display Link sur Sputnik, lire `MC_KEYS_RAW` sur un Display Board pour
vérifier les touches au serveur. Chaque touche doit passer de 0 à 1 durant
l'appui puis revenir à 0 au relâchement. Cocher la confirmation seulement après
cette vérification. Si le Typewriter émet des impulsions ou mémorise un état,
ce mode maintenu n'est pas compatible : aucune durée de maintien n'est inventée.

Après configuration : Enable à zéro avec toutes les touches relâchées pendant
au moins deux mises à jour serveur, puis Enable positif sans touche appuyée.
Les commandes peuvent ensuite être utilisées simultanément :

| Sortie | Touches / plage |
| --- | --- |
| `Forward demand` | W − S, de -1 à +1 |
| `Left demand` | Q − D, de -1 à +1 |
| `Vertical demand` | Space − Shift, de -1 à +1 |
| `Commands valid` | 1 seulement lorsque le clavier est activé et configuré |
| `Hold requested` | 1 lorsque le clavier actif ne demande aucun mouvement |

W+Q donne une diagonale avant-gauche normalisée, sans lacet. Les opposés
s'annulent. Les consignes sont relatives au véhicule. `Forward demand` et
`Left demand` peuvent alimenter les entrées homonymes du `vehicle-mixer` en
profil 2, sous réserve de vérifier `Commands valid` et de qualifier l'inclinaison.
**Ne pas brancher `Vertical demand` sur `Collective demand`** : monter/descendre
est une consigne de vitesse verticale que la future boucle altitude devra
intégrer, puis maintenir lorsque la touche est relâchée. Cette boucle n'est pas
encore fournie ; `Hold requested` ne prouve pas un maintien de position.

Une modification de configuration, une perte de contexte serveur, une valeur
Link invalide ou une rupture d'horloge invalide les commandes et exige une
nouvelle activation au neutre. Un Link ne fournit ni identité de l'émetteur ni
battement de connexion authentifié : une déconnexion du Typewriter peut être
indiscernable d'un relâchement, ou laisser temporairement un signal en cache.
Ces sorties ne certifient donc pas une liaison de vol ni un autopilote ;
`Flight qualified` reste zéro. Aucun signal n'est transmis par ce nœud.

## Contrôleur quad avec sorties moteur — 0.1.13

Importer `mintcraft-quad-flight.clipboard.txt` pour obtenir le graphe complet
levier + clavier + contrôleur. Les quatre fréquences des transmissions se
configurent **dans `quad-controller`**, pas dans le clavier. Lire
[QUAD-FLIGHT.md](QUAD-FLIGHT.md) pour le modèle local obligatoire, le Kalman,
la stabilisation, l'activation et le repli. Cette version émet réellement des
signaux après configuration et autorisation ; elle reste expérimentale, avec
calibration manuelle et sans vol Minecraft validé.

## Poussée et masse automatiques — 0.1.13

Le contrôleur propose maintenant un mode physique pour un quad symétrique à
quatre petits rotors verticaux identiques, avec Aeronautics/Simulated 1.3.2 et
Sable 2.0.6 aux réglages Overworld par défaut. Il lit masse et inertie, calcule
pression et poussée, puis recalcule les commandes en vol. Dans ce mode, les
anciennes lignes `trim,min,max,dY,dPitch,dRoll,repli` restent vides. Seules les
dimensions et hypothèses matérielles sont à confirmer. Lire
[le mode physique du guide](QUAD-FLIGHT.md) avant activation. Le résultat reste
expérimental et n'a pas été testé en jeu.

## Diagnostic Link indépendant — 0.1.13

`mintcraft-link-test.clipboard.txt` ajoute un seul nœud de test radio. Ce test
utilise l'API native `transmitWirelessRedstone` sans contrôleur de vol, sans masse
et sans calibration : Sputnik peut tester la radio même hors structure simulée.
Il ne remplace pas l'assemblage nécessaire au contrôleur de vol.

1. Garder le contrôleur du quad désactivé. Placer un Redstone Link **récepteur**
   sur un bloc ordinaire à côté de Sputnik, avec une lampe ou une sortie visible.
2. Réserver une paire d'objets entièrement différente des canaux moteur/clavier.
   L'ordre des deux objets doit être le même sur le récepteur et le nœud test.
3. Importer le nouveau nœud, sauvegarder, fermer et rouvrir, puis configurer la
   paire. Laisser sa case décochée, sauvegarder/fermer une fois.
4. Cocher « Émettre 15 ... TEST LAMPE », puis sauvegarder/fermer. Le serveur
   rafraîchit une demande de signal 15 ; la lampe constitue la preuve physique
   de réception. Décocher et sauvegarder pour envoyer zéro et terminer le test.
5. Répéter avec le récepteur sur le véhicule si le test dans le monde fonctionne.

Ne jamais employer une fréquence de transmission/hélice pour ce test : 15 peut
arrêter une transmission. Le test est conçu uniquement pour une lampe séparée.
`Requested signal` ou `MC_LINK_TEST` confirment un appel logiciel, **pas la réception**.
Si la lampe fonctionne, le blocage est dans l'activation/configuration du quad ;
lire `MC_QUAD` via Display Link. Si elle ne fonctionne pas malgré la configuration
sauvegardée, ce résultat oriente vers la fréquence, le mode récepteur, la portée,
l'exécution du graphe ou l'intégration Create/Cosmonautics ; la cause exacte reste
à établir. Les essais automatisés ne remplacent pas ce test physique.

## Motifs de refus détaillés — 0.1.13

Le contrôleur ne se limite plus à « Configurer les fréquences et paramètres ».
Sa sortie `Status` donne les conditions réellement refusées côté exécution :
`CONFIRM` (confirmation non reçue), `ENABLE_BIND` (description du levier),
`KEY_COUNT` (nombre de fréquences clavier), `DUP_n` (collision entre rôles),
`ROTOR_n` (paire manquante), `PARAM_*` / `PHYS_*` (champ invalide), `MODEL`
(modèle physique refusé), puis `BASELINE`, `KEYS_WAIT` ou `KEYS_HELD` pour les
étapes d'activation. `MASS` signale une masse serveur absente. Ces messages
n'autorisent aucune commande supplémentaire et ne désactivent aucun contrôle.

Le graphe complet contient maintenant **quatre nœuds et neuf fils** : le
`String Display` natif `MintCraft quad-status` est déjà raccordé à `Status`.
Dans le Display Link, sélectionner **Node: MintCraft quad-status**. Les clés
créées par `display(...)` existent côté serveur mais leur carte n'est pas
synchronisée dans le menu client du mod ; ne pas dépendre d'une sélection
« Bridge: MC_QUAD » pour le diagnostic.

Pour cette mise à jour, sauvegarder le graphe et les réglages existants, mettre
l'autorisation à zéro, puis remplacer l'ancien graphe quad par le nouveau.
Reconfigurer les fréquences et dimensions ; ne pas garder deux contrôleurs qui
émettent sur les mêmes rotors. L'ancien graphe sauvegardé reste réimportable.

## Masse et commandes observables — 0.1.13

Le message « Boucle expérimentale en cours » indique une boucle exécutée, **pas
une stabilisation physiquement validée**. Le mode physique lit déjà la masse via
`getShipMass()` et les inerties diagonales via `getInertiaTensor()` : il refuse
l'activation si elles ne sont pas positives. Cela n'identifie ni le centre de
masse ni l'emplacement réel des hélices.

Pour conserver un graphe déjà configuré, importer uniquement
`mintcraft-flight-audit.clipboard.txt`. Ce complément ajoute un lecteur sans
actionneur et un `String Display` raccordé. Aucun réglage de fréquence à saisir.
Brancher les six entrées du lecteur :

| Source existante | Entrée de `flight-telemetry` |
| --- | --- |
| `quad-keyboard` → Commands valid | Keyboard valid |
| `quad-keyboard` → Forward demand | Forward demand |
| `quad-keyboard` → Left demand | Left demand |
| `quad-keyboard` → Vertical demand | Vertical demand |
| `quad-controller` → Active | Controller active |
| `quad-controller` → Target altitude | Target altitude |

Sauvegarder et fermer, puis choisir **Node: MintCraft flight-screen** dans le
Display Link. Lire le panneau physique : `m` est la masse native (kg), `I` les
inerties X/Z, `A` le contrôleur actif, `K` le clavier valide, `F/L/Y` les consignes
reçues du clavier, `h` l'altitude native suivie de sa cible. Une entrée non câblée
vaut zéro dans Sputnik : connecter les six fils avant d'interpréter ces zéros.
L'éditeur représente souvent le client et peut y montrer une masse nulle ; le
panneau physique lit le graphe serveur. Le complément ne certifie pas la source
ni la bonne réception physique d'une commande moteur.

Exemple de diagnostic pendant un appui Espace : `K=1 Y=1` doit être suivi d'une
cible d'altitude qui augmente. Si `Y` reste zéro, examiner Typewriter/fréquences ;
si `Y=1` mais la cible reste fixe alors que `A=1`, examiner le fil et l'exécution
du contrôleur ; si la cible augmente mais pas le véhicule, examiner réserve de
poussée, mécanique et modèle. Un centre de masse déplacé (par exemple par un
panneau ajouté d'un côté) ou une association avant/arrière erronée peut dégrader
la stabilisation malgré une masse totale correctement lue.

Le graphe complet destiné à une installation neuve contient ces deux nœuds en
plus, avec le sélecteur depuis la 0.1.19 : **sept nœuds, dix-sept connexions**. Une correction séparée arrondit la toute
première consigne rotor, qui pouvait être fractionnaire dans le mode physique ;
le modèle reste fractionnaire en interne, seules les sorties matérielles sont
entières. Les essais de bout en bout couvrent levier, clavier, propagation du
graphe, contrôleur et audit dans une plante simulée avec inertie, densité et
retard de régime ; cela ne reproduit pas le serveur du joueur.

## Premier défaut conservé après arrêt — 0.1.13

Une erreur de diagnostic pouvait remplacer le motif d'un arrêt par `BASELINE`
dès la mise à jour suivante. Le contrôleur était bien en défaut, mais son
message invitait à recommencer l'activation au lieu d'expliquer l'échec.

La sortie `Status` conserve maintenant **le premier défaut**, préfixé `FAULT`,
avec le tangage, le roulis et la masse observés à cet instant. Une sortie texte
`Last fault` fournit aussi ce message. Les défauts ultérieurs ne l'effacent pas.
La dernière cible d'altitude et le diagnostic de poids restent consultables
après arrêt ; ce sont les dernières données du contrôleur, pas un maintien actif.

La faute est effacée après une séquence explicite d'autorisation à zéro, au
moins deux observations serveur nouvelles et configuration de nouveau valide.
Garder le levier allumé ne redémarre pas le contrôleur. Les gardes d'attitude,
de modèle, de contexte et le repli ne sont pas supprimés. Les causes de perte
d'horloge, masse ou changement de configuration sont distinguées.

Le test de régression force un dépassement d'inclinaison après activation et
vérifie que cette première cause reste affichée pendant plusieurs mises à jour,
y compris après une deuxième faute. Cela corrige le diagnostic ; la cause de
l'instabilité réelle du véhicule reste à établir avec les observations serveur.

## Réarmement et transmission corrigés — 0.1.13

La reprise après défaut passe par le levier à zéro ; elle ne nécessite plus que
le modèle soit déjà valide pour acquitter la faute. Le repli des anciens canaux
reste maintenu. Après réparation de la configuration, `LEVEL_WAIT` attend que le
quad soit redressé avant un nouveau départ. Le clavier attend les touches au
neutre après un OFF réel, y compris lors d'un basculement rapide du levier.

Le modèle de transmission corrige le **bypass du signal 0 : 256 RPM restent
256 RPM**, tandis que 1 donne 224 et 15 l'arrêt, dans le sens réducteur.
**Moteur sur arbre, hélice sur engrenage** est l'hypothèse de ce profil. Le sens
inverse peut multiplier 256 en 292,6 RPM au signal 1 et bloquer la transmission
par dépassement de vitesse. Lire QUAD-FLIGHT avant d'attribuer l'arrêt au clavier.

Le panneau de statut montre maintenant les commandes reçues et les quatre
niveaux demandés (`R=a/b/c/d`), avec masse et altitude cible. Les tests couvrent
le réarmement sans redémarrage, les 16 états réels de la transmission et un
stationnaire simulé entre les états 0/1 ; la mécanique du véhicule réel reste
à vérifier.

</details>
