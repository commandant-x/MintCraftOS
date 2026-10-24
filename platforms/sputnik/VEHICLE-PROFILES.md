# Groupes et fonctions de commande

Le modèle décrit les commandes physiques, leurs effets observés et les degrés de
liberté réellement indépendants. Un nom « hélicoptère » ne certifie pas six axes.
Un groupe décrit une chaîne mécanique ou un rôle commandé ensemble, pas des
moteurs proches. Une banque peut avoir plusieurs canaux Link (transmission,
clutch, inverseur) : six groupes fonctionnels ne signifient pas six fréquences.

## Venator décrit par l'utilisateur

| Fonction | Membres | Commande logique | Interprétation |
| --- | --- | --- | --- |
| Propulsion arrière gauche | 2 moteurs | Demande signée gauche | Positif avance, négatif recul, zéro arrêt de propulsion |
| Propulsion arrière droite | 2 moteurs | Demande signée droite | Indépendante de la gauche |
| Sustentation | 4 pales | Quatre commandes indépendantes confirmées | Transmission 0–15 ; **15 bloque les pales**, jamais un neutre de sustentation supposé |

Le fichier `profiles/venator.json` conserve ces six groupes sans inventer de
fréquence, position physique ou courbe RPM. Ce fichier est une description de
développement, pas un graphe à importer ni une configuration déjà qualifiée.

La configuration de chaque groupe comprend fréquence(s) Link réelles,
transmission, éventuel clutch/inverseur et état de reprise physique. Les courbes
signal → RPM → réponse du véhicule doivent être relevées ; `15 - signal` n'est
pas supposé être une courbe de poussée linéaire.

Deux moteurs derrière une transmission commune restent **un seul axe de commande**.
Pour ce Venator, les quatre pales ont des commandes indépendantes : collectif
et corrections de roulis/tangage sont donc candidats à mesurer. Pour un autre
vaisseau où elles partagent une commande, ces corrections indépendantes ne
sont pas supposées disponibles. La stabilisation mécanique existante doit
être distinguée d'une autorité de correction disponible à l'ordinateur.

## Mixer différentiel fourni

Importer `mintcraft-drive-mixer.clipboard.txt` ou coller `mintcraft-drive-mixer.lua`
dans un nouveau nœud Lua. Entrées **Drive** et **Left turn**, chacune de -1 à +1.
Les sorties sont des **demandes signées normalisées, pas des niveaux redstone**.
Ce nœud n'émet aucune commande et n'arme pas un pilote.
Ne pas relier directement une demande normalisée à une transmission 0–15.

- Drive = 1, Turn = 0 : G +1, D +1.
- Drive = 0, Turn = +1 : G -1, D +1, rotation gauche sur place.
- Drive = 0, Turn = -1 : G +1, D -1, rotation droite sur place.
- Drive = 1, Turn = +1 : G 0, D +1, virage gauche par arrêt de la banque gauche.
- Drive = -1, Turn = 0 : G -1, D -1, marche arrière.
- Drive = -1, Turn = +1 : G -1, D 0, demande de rotation gauche pendant le recul.

Mode par défaut : pivot de la banque intérieure en mouvement, contre-rotation
sur place. `Blend mode = 1` active `(Drive-Turn, Drive+Turn)`, avec une seule
normalisation commune préservant le rapport des deux demandes. Les signes se
qualifient physiquement : des moteurs montés en miroir peuvent nécessiter une
inversion de configuration.

L'inverseur ne doit pas être basculé en charge simplement parce que le signe de
la demande change. Une intégration d'actionnement doit demander l'arrêt de la
banque, attendre des RPM réellement faibles, commander l'inverseur, vérifier son
retour puis remettre de la puissance. Aucun de ces retours n'est inventé ici.
Le helper de développement `drive_mixer.transmission` ne choisit que dans une
liste de RPM réellement relevés ; il refuse l'extrapolation et n'est pas une
preuve automatique de réception.

## Quatre pales indépendantes

Les entrées `Lift collective` (0–1), `Front bias` et `Right bias` (-1 à +1)
donnent quatre demandes `Front left/right`, `Rear left/right`. Ce repérage est à
associer une fois aux quatre commandes physiques. Le mélange de démonstration
suppose seulement un repérage nominal symétrique ; il ne certifie pas la géométrie.
Les corrections sont réduites ensemble à la saturation sans changer la moyenne
des demandes. **Cela ne prouve pas que la poussée réelle reste constante**, car
les moteurs, bras de levier et courbes de transmission doivent être identifiés.

`Drive STOP` annule les demandes de propulsion sans modifier les quatre demandes
de sustentation. Le nœud ne déclenche ni arrêt général, ni signal 15 sur les pales.
Un lacet par les pales ne se suppose pas : il dépend des couples et des sens de
rotation réellement disponibles ; les banques arrière peuvent fournir le lacet.

## Autres architectures

| Configuration | Groupes à décrire | Ce que les mesures doivent établir |
| --- | --- | --- |
| Airship | Chauffe/ballons, propulsion, éventuel lacet | Maintien Y, avance/recul et rotation seulement s'ils sont commandables |
| Quadcopter + propulsion | Quatre sustentations indépendantes, propulsion(s) | Collectif, roulis/tangage, lacet selon couples réellement disponibles, avance séparée |
| Hélicoptère + propulsion + yaw | Rotor principal, propulsion, actionneur de lacet | Autorité verticale et de lacet ; cyclique/roulis/tangage uniquement si commandables |
| Montage asymétrique | Chaque canal physique indépendant | Réponses couplées mesurées et axes encore commandables après saturation/panne |

Le contrôleur commun transforme une consigne altitude/vitesse/cap en demandes de
forces/couples, puis les alloue aux groupes mesurés. Les fonctions absentes restent
indisponibles ; il n'exige pas arbitrairement deux brûleurs ou deux moteurs.

## Arrêts et dégradation

« Arrêter le déplacement » met la propulsion horizontale au neutre **en conservant
le maintien vertical qualifié**. « Reprise manuelle » transfère aux commandes
physiques. Couper toutes les pales est un arrêt mécanique distinct, à réserver
au cas explicitement voulu. Le signal d'arrêt du groupe n'est pas le trim aérien.
L'ancienne passerelle Link générique qui demande zéro ne gère ni ces distinctions
ni les transmissions inversées : ne pas l'utiliser comme STOP global de vol.

Une variation de masse impose d'estimer le nouveau trim à consigne Y conservée,
sans nouveau balayage en vol, tant qu'il reste de l'autorité. Une vraie perte de
sustentation ne permet pas de promettre une altitude constante. Les bancs moteur
et la correction verticale doivent avoir leurs validations et limites propres.

## Ce qui reste nécessaire dans Sputnik

Le mixer ci-dessus est disponible et testé, **pas un autopilote de vol**. Le
monitor actuel ne donne pas l'identité Sable ni les retours brûleur/mécaniques
nécessaires à une calibration automatique fiable. Il faut des retours physiques
exposés par les nœuds/capteurs du serveur ou une intégration serveur dédiée pour
aller des demandes de ce mixer à un pilote qualifié. Les limites de taille NBT
restent appliquées à chaque nœud téléversable ; la grosse bibliothèque ne retourne
pas dans le tableau de bord.
