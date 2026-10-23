# A.8 — surveillance des sources mécaniques observées (0.18.88)

Cet incrément partiel du lot A complète le diagnostic cinétique de 0.18.86.
Il ne termine pas Autopilot 2 et ne certifie aucun axe supplémentaire.

## Association mesurée, dans la session

Le nouvel observateur `system.navigation.motor_health` ne lit aucun périphérique
et ne commande aucun bloc. `flightd`, seule autorité physique, lui transmet les
retours des essais moteur déjà prévus : 60 modes ou les quatre contrôles de
réutilisation. Aucun essai ni délai de poussée n'est ajouté.

Pour associer un clutch à une banque, il faut au moins deux observations
distinctes dans chacun des états électriques confirmés : deux banques débrayées,
gauche seule embrayée et droite seule embrayée. Le booléen physique `disengaged`
doit correspondre sans contradiction aux trois états. Le récepteur doit avoir
confirmé les six valeurs de commande avant chaque observation. Un rapport nul
avec un clutch embrayé n'est pas une preuve du débrayage.

Une source propulsive n'est associée que si sa rotation non nulle et ses arêtes
Create `sourceId` observées remontent réellement vers ce clutch. Une autre banque
sur le chemin ou une source compatible avec les deux banques interdit
l'association. Les coordonnées et la proximité des récepteurs ne servent pas de
preuve. Les données restent un **sous-ensemble observé**, jamais une garantie que
chaque moteur de la banque est surveillé.

La preuve reste en RAM, privée au service et liée au job de calibration, à l'UUID
et aux six fréquences. Elle est reconstruite après redémarrage ou nouvelle
calibration ; elle n'est pas restaurée depuis un rapport utilisateur. Un changement
de commande ou une régression d'horloge l'invalide. Les limites sont 64 clutches,
32 sources, 128 éléments par chemin et 1024 éléments cinétiques par lecture.

## Dégradation pendant le guidage

Après une calibration complète, les observations fraîches et postérieures aux
commandes confirmées peuvent constater, sur une source associée et sollicitée :

- un clutch physiquement débrayé ;
- une surcharge sur son chemin cinétique réel ;
- une rotation nulle malgré une rotation théorique non nulle ;
- un chemin interrompu ou un clutch associé devenu introuvable ;
- une absence prolongée de rotation malgré une réponse attendue mesurable.

Les quatre premiers cas nécessitent deux observations distinctes espacées d'au
moins 0,5 s ; le dernier huit. Une interruption de plus de deux secondes casse
la série. Les phases de débrayage ne sont pas des défauts. Les données absentes
ou ambiguës ne produisent pas une panne inventée ; si le diagnostic mécanique
optionnel entier manque, la surveillance de réponse physique existante demeure.

Une panne qualifiée suspend le guidage horizontal, débraye les deux banques,
conserve la consigne et le contrôleur verticaux encore vérifiés, puis interdit
la réutilisation ou l'export du modèle horizontal avant requalification. Les
protections de capteurs, brûleurs, propriétaire, permissions et STOP ne sont
pas atténuées. Une perte de contrôle vertical reste traitée par ces protections.

`flightd.status().mechanicalDiagnostic` expose des comptes par banque, fraîcheur,
limites et motif sans identifiants mécaniques. La vue native **Etat** affiche le
retour courant comme couverture partielle. Ce diagnostic n'est pas un certificat
de santé de tout le véhicule.

## Validation et limites

Les tests unitaires couvrent les cinq défauts, l'isolation d'une surcharge hors
chaîne, l'absence de diagnostic, la fraîcheur, les doublons, les interruptions,
les contradictions, les sources ambiguës et les limites de mémoire. Le simulateur
de service exerce les commandes Link et les retours physiques, la reconstruction
de la preuve après reprise, puis une surcharge de source avec des récepteurs
électriques encore fonctionnels. L'objectif est de vérifier le maintien vertical
et le refus du réarmement horizontal, sans fausse validation de calibration.

Le JAR reste Vehicle Bridge 0.2.3. Aucun essai réel Minecraft n'a été réalisé.
Le diagnostic n'identifie pas les pannes non observables ni les nouveaux axes ;
le terrain, le décollage et l'atterrissage restent à développer.

Qualification de la livraison : 172 suites Lua passent sur les sources et sur
les modules installés compactés ; 378 sources et 172 chunks installés compilent.
L'interpréteur Cobalt 0.9.9 extrait du CC:Tweaked installé compile les 172 chunks
et exécute le décodage/comparaison exacte/compilation des 171 modules. La boucle
`flightd.step` reste à 55 captures, sous la limite Cobalt de 60.

Le scénario de disque à 1 000 000 octets, incluant 100 000 octets de données
utilisateur, mesure 894 469 octets installés et un pic de 958 752 octets durant
mise à jour/checkpoint/restauration. La migration 0.18.87 → 0.18.88 → 0.18.87 →
0.18.88 atteint 933 960 octets au maximum. Les reprises après interruption et
l'absence d'historique permanent par défaut restent vérifiées.

Retour au comportement 0.18.87, après arrêt explicite du pilotage :

```lua
wget run https://raw.githubusercontent.com/commandant-x/MintCraftOS/438c1e00c359cf8a7fa4234e21952c21e4495654/install.lua
```

Ce retour de code ne supprime pas les profils, cartes, rapports ou fichiers
personnels. Les configurations ne constituent jamais des preuves physiques.
