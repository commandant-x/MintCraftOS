# MintCraft Sputnik 0.1.8

Édition autonome pour **Cosmonautics 26.08.307, Minecraft 1.21.1**. CC:Tweaked et
Vehicle Bridge ne sont pas nécessaires. La version de votre serveur reste à
confirmer. Les versions anciennes de Cosmonautics peuvent utiliser un autre
éditeur et un format de graphe incompatible.

## Téléversement sans accès aux fichiers du serveur

1. Télécharger `dist/mintcraft-sputnik-0.1.8.zip` sur votre ordinateur personnel
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

## Clavier Linked Typewriter — 0.1.8

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

## Contrôleur quad avec sorties moteur — 0.1.8

Importer `mintcraft-quad-flight.clipboard.txt` pour obtenir le graphe complet
levier + clavier + contrôleur. Les quatre fréquences des transmissions se
configurent **dans `quad-controller`**, pas dans le clavier. Lire
[QUAD-FLIGHT.md](QUAD-FLIGHT.md) pour le modèle local obligatoire, le Kalman,
la stabilisation, l'activation et le repli. Cette version émet réellement des
signaux après configuration et autorisation ; elle reste expérimentale, avec
calibration manuelle et sans vol Minecraft validé.

## Poussée et masse automatiques — 0.1.8

Le contrôleur propose maintenant un mode physique pour un quad symétrique à
quatre petits rotors verticaux identiques, avec Aeronautics/Simulated 1.3.2 et
Sable 2.0.6 aux réglages Overworld par défaut. Il lit masse et inertie, calcule
pression et poussée, puis recalcule les commandes en vol. Dans ce mode, les
anciennes lignes `trim,min,max,dY,dPitch,dRoll,repli` restent vides. Seules les
dimensions et hypothèses matérielles sont à confirmer. Lire
[le mode physique du guide](QUAD-FLIGHT.md) avant activation. Le résultat reste
expérimental et n'a pas été testé en jeu.
