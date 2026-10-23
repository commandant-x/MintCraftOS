# B.1 — archives et recontrôles physiques — 0.18.90

Cet incrément poursuit Ascendancy. Il n'annonce pas la fin des lots A–E.
Le maintien mesuré, STOP/F10, les propriétaires, permissions, secours, reprise
manuelle et absence de réarmement au redémarrage restent en vigueur.

## Modèles génériques

L'activation automatique demande un nouveau relevé de structure lorsque le bridge
expose les pages de géométrie. Aucun essai de sortie ne démarre pendant ce relevé.
Une géométrie partielle ou sans empreinte n'autorise aucune réutilisation : la
caractérisation fraîche reste disponible. Les absences sont des diagnostics,
pas des capacités inventées.

Un candidat historique exige :

- même UUID, inventaire frais complet et nouvelle empreinte structurelle identique ;
- affectations physiques identiques : identifiants, périphériques, fréquences,
  neutres, secours, bornes et mélange ; les indicateurs de validation ne sont pas
  des preuves réutilisées ;
- masse et unité observées compatibles, inertie symétrique définie positive avec
  unité connue et centre de masse observé compatibles ;
- schéma reconnu et mesures brutes bornées dont les horloges, unités, repères,
  retours RX et intervalles isolés permettent de reconstruire la réponse ;
- domaine de mouvement exploitable dans la pose actuelle et conditionnement
  suffisant. Sinon les essais frais reprennent, sans croire les coefficients sauvés.

Les seuils de comparaison de métadonnées sont 0,5 % pour masse/inertie et 0,01 bloc
pour le centre de masse. Ce sont des règles conservatrices d'invalidation, pas
une affirmation de précision des capteurs. Les seuils de comparaison d'inertie
utilisent la diagonale pour traiter les termes hors diagonale proches de zéro.

Le service reconstruit le modèle depuis les observations brutes. Il ne charge
aucune sortie active, aucun propriétaire et aucun ancien certificat de vol.
Il exige ensuite un neutre fraîchement reçu et stationnaire, puis répète les
mouvements opposés et le retour en boucle fermée. Les impulsions isolées de chaque
sortie sont évitées uniquement pour un candidat ainsi requalifiable. La stratégie
d'inclinaison est à nouveau observée passivement et requalifiée séparément.

L'horloge originale des dérivées reste enregistrée ; les nouveaux essais portent
leur horloge actuelle. Des mesures anciennes ne deviennent jamais des capteurs
frais par simple rechargement.

## Données et interface

Après qualification, le service archive automatiquement le rapport si permissions
et espace le permettent. Une caractérisation sans vol s'archive après application
du secours. Calibration affiche la réutilisation, les essais courants et les
refus d'archivage. Le bouton d'enregistrement reste disponible pour réessayer.
Un échec d'archivage conserve les mesures en RAM et ne coupe pas le maintien.

Le schéma 2 est conservé dans `/system/config/navigation-response-v2.cfg`, au plus
32 768 octets, avec transactions temporaires et contrôle d'espace. L'ancien
`navigation-response.cfg` reste intact. Le retour au code 0.18.89 ignore le nouveau
fichier ; aucune ancienne version ne l'interprète comme une autorité de vol.
Un trim ou une dégradation ne devient pas un nouveau modèle qualifié.

## Chauffe et moteurs indépendants

Les archives de chauffe existantes ne sont plus invalidées par le seul changement
d'affectation du drivetrain. Tous les autres liens verticaux, capteurs, structure,
masse, plage de chauffe et qualités du modèle restent contrôlés. Les essais
verticaux, secours et priorité sont rejoués.

Le modèle moteur ne peut être candidat que si son affectation propre correspond
également. Un changement de fréquence moteur entraîne les nouvelles mesures
moteur, tout en conservant la table de chauffe indépendante. Un changement du
brûleur ou de sa mesure verticale invalide toujours cette table.

## Changements physiques en vol

Le maintien générique surveille aussi l'inertie et le centre de masse observés.
Un changement ou une perte de disponibilité suspend l'horizontal et conserve la
consigne verticale si cette autorité est déjà qualifiée. Le contrôleur utilise
son trim borné, sans nouvelles impulsions d'identification en mission. Le motif
précise masse, inertie ou centre de masse. Les métadonnées qui changent pendant
la calibration empêchent de certifier un modèle devenu incohérent.

Cela ne garantit pas qu'un appareil endommagé conserve sa portance. Une perte
réellement observée d'autorité essentielle reste une cause de secours configuré.
L'adaptation locale ne restaure pas automatiquement un modèle horizontal suspendu.

## Qualification et limites

Les tests intégrés observent les sorties du service et la plante simulée :
relevé neuf, absence d'armement depuis le fichier seul, nouveau neutre, vrais
aller/retour, horloges distinctes, refus d'inertie/masse/COM/liaisons incohérents,
archivage, fermeture, redémarrage et maintien du même Y après changement physique.
Le test des moteurs existant vérifie aussi que la chauffe seule se réutilise
lorsqu'une fréquence moteur historique diffère, sans réutiliser les anciens moteurs.

Aucun essai Minecraft n'a été effectué ici. La calibration universelle depuis
un neutre inconnu, les observations de terrain, la planification 3D, les phases de
vol et les missions persistantes restent des travaux actifs. L'adaptation passive
actuelle ne prétend pas recertifier les gains horizontaux ni le freinage.

Pour revenir à 0.18.89 après STOP :
`wget run https://raw.githubusercontent.com/commandant-x/MintCraftOS/main/tools/rollback-compatible.lua 99311e09fe856ea42bba7fddcd717204c72192a8`
Les fichiers personnels, configurations et archives de nouveau schéma restent disponibles.

Résultats : 182 suites sources et 182 suites compactées passent. Les 182 chunks
installés compilent dans Cobalt ; le probe compare exactement les 181 corps Lua
et compile leurs sources décodées. L'installation, comptée à au moins 512 octets
par fichier/dossier avec 100 000 octets de données utilisateur, occupe 733 598
octets ; petite mise à jour/checkpoint/retour : pic 762 058. Migration réelle
0.18.89 → 0.18.90 → retour compatible → réinstallation : pic 799 652. La variante
avec checkpoint retenu explicitement atteint 865 780 au pic. Les interruptions
et le mode sans historique conservent les données utilisateur.
