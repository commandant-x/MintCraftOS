# C.1 — terrain réel chargé et cache ATLAS — 0.18.91

Cet incrément ne termine pas Ascendancy. Il ajoute l'observation et l'affichage du
terrain statique ; le planificateur 3D, la vérification complète du volume et les
missions autonomes restent à intégrer. Les routes existantes gardent leur
confirmation de trajet dégagé et ne sont pas présentées comme des routes avec
évitement. Aucun essai Minecraft n'a été effectué dans cet environnement.

## Activation serveur

Vehicle Bridge 0.4.0 ajoute l'API séparée `mintcraft_terrain`. Ses lectures sont
refusées par défaut. L'administrateur du serveur active explicitement les Computers
autorisés dans `serverconfig/mintcraft_vehicle_bridge-server.toml` du monde :

```toml
terrainReadsEnabled = true
terrainComputerIds = [7]
```

Remplacer `7` par l'identifiant réel visible dans Settings > System. La liste vide,
une désactivation ou un identifiant absent refuse les lectures ; au plus 256 IDs
sont admis. Le code ne modifie pas cette politique ni les mods du serveur.
Arrêter normalement le serveur, remplacer le JAR précédent par le nouveau JAR
0.4.0 et redémarrer ; ne pas garder deux versions du bridge. Les anciennes API
véhicule/RX restent compatibles avec le code 0.18.90. Les JAR précédents et leurs
SHA-256 restent disponibles pour un retour manuel.

Dans MintCraftOS, Navigation déclare séparément `navigation.terrain` pour la
lecture et `navigation.map.write` pour la sauvegarde. Le service vérifie les
permissions effectives et l'existence du propriétaire, y compris après chaque
appel asynchrone. Une permission d'observation n'accorde aucune commande de vol.

## Utilisation

Ouvrir Navigation > Control > Atlas. Le service détecte seul la dimension,
l'identité du vaisseau et la position monde du Computer ; aucune saisie de nom
technique n'est nécessaire. Le Computer doit être sur un sublevel Sable dont la
pose fraîche est disponible. La couche affichée utilise l'altitude cible du panneau.

Le lecteur parcourt les neuf sections voisines de cette couche. L'affichage
conservateur emploie des cellules de 4 blocs : un seul bloc non-air rend toute sa
cellule occupée. Le fond reste inconnu lorsque la zone n'a pas été lue, est trop
ancienne, n'est plus chargée ou n'est pas autorisée. Les données du vaisseau et
les contacts Combat ne sont jamais utilisés comme terrain du monde.

« Enreg. » sauvegarde les cellules et leur provenance dans un fichier distinct
par dimension, sous `/system/config/atlas-terrain-v1/`. L'ensemble du dossier est
borné à 65 536 octets et 32 fichiers ; aucun fichier existant n'est supprimé pour
faire de la place. Les archives inconnues ou incohérentes sont conservées et
refusées. Un redémarrage charge uniquement de l'historique : une archive ne
redevient jamais une observation fraîche sans nouveau relevé réel.

## Acquisition bornée et lecture seule

- Une page contient exactement une section monde de 16³ blocs déjà chargée,
  alignée, dans les bornes verticales réelles et à 128 blocs maximum du Computer
  réellement transformé depuis sa pose Sable.
- L'API appelle `getChunkNow`, puis lit directement les états du chunk existant.
  Elle ne demande aucun chunk, aucune génération, aucune forme de collision qui
  pourrait consulter des voisins, et aucune modification du monde.
- Chaque Computer est limité à une page par cinq ticks serveur ; le budget global
  est de 16 384 blocs par tick. Le contexte a sa propre limite de 32 lectures par
  tick et cinq ticks par Computer. BUSY ne crée jamais de nouvelles données.
- Chaque résultat contient dimension, UUID, repère monde, unité bloc, horloge de
  source, tick de jeu et tick serveur. Un changement de dimension ou un retour en
  arrière de l'horloge renouvelle l'identité de l'épisode de source.
- Le worker Lua est indépendant du dessin et des boucles RX rapides. Il ne lit rien
  sans bail explicite du propriétaire. Fermer ou quitter la carte libère ce bail ;
  son expiration et la révocation des permissions empêchent les appels suivants.

Le cache contient au plus 64 pages de 64 cellules conservatrices. Une page dure
cinq secondes au maximum. Les nouvelles observations remplacent les plus anciennes
lorsque le cache est plein. Un résultat UNLOADED invalide immédiatement la page
concernée. Les replays et les changements de repère, namespace, UUID ou horloge
ne renouvellent pas son âge.

Le contrat `atlas.terrain` est enregistré dans `system.ascendancy.sources` : il
retourne une copie autorisée du cache et n'acquiert jamais de périphérique.
Les requêtes de volumes ont un budget maximal de 4 096 cellules et refusent
l'inconnu ; cela ne constitue pas encore un certificat d'itinéraire.

## Limites physiques

L'air observé n'est pas une preuve d'absence d'entités, de vaisseaux mobiles ou
de formes complexes débordant leur bloc. `dynamicCoverage` reste explicitement
faux. La classification est une occupation statique conservatrice, pas un maillage
de collision Minecraft ni un détecteur de contact. La surface d'arrivée,
l'atterrissage et l'évitement garanti restent indisponibles dans cet incrément.

Le relevé est local et partiel. Une destination hors des données connues n'est
pas déclarée accessible. Les fonctions de contrôle, les consignes et le secours
restent exclusivement dans `flightd` ; `atlasd` ne possède aucune sortie physique.

## Tests et retour arrière

Les tests Java vérifient les permissions serveur, les bornes, le thread principal
et l'absence de méthodes de chargement, de formes de collision et de modification
du monde. Les tests Lua vérifient les namespaces/horloges, les cellules
conservatrices, les données absentes/périmées, l'immutabilité, les budgets, les
interdictions de lecture après perte de bail/propriétaire/permission, y compris
pendant un RPC, la sauvegarde et l'affichage natif sans acquisition.

Après STOP, retour au code 0.18.90 :
`wget run https://raw.githubusercontent.com/commandant-x/MintCraftOS/main/tools/rollback-compatible.lua 15211ba5bb6e50d067a8c11b822234b4e1cc63f3`
Les cartes et configurations restent sur disque. Le JAR 0.4.0 peut rester en place
ou être remplacé manuellement par 0.3.0 après arrêt normal du serveur ; l'ancien
OS n'appelle pas l'API de terrain.

Qualification automatisée : la campagne de 185 suites sources et 185 suites
compactées passe ; les dernières gardes de données synthétiques, archives
malformées et limite de fichiers sont rejouées sur les deux représentations.
Cobalt compile les 184 chunks installés et le probe compare/compile exactement
les 183 corps Lua. Le build et les tests Java 0.4.0 passent contre Sable 2.0.6.
SHA-256 du JAR :
`5fccac9d00da5176ed0aae9cff72e040e2e15a2f9b7f15739c17467b432752c4`.

Disque conservateur, au moins 512 octets par fichier/dossier et 100 000 octets de
données utilisateur : 742 368 octets installés ; petite mise à jour/checkpoint/
retour : pic 770 828 ; parcours 0.18.90 → 0.18.91 avec checkpoint et retour :
pic 834 053. Migration réelle depuis 0.18.88, retour compatible et réinstallation :
pic 908 567. Les sauvegardes de terrain sont des données supplémentaires bornées ;
leur manque de place entraîne un refus, sans suppression de données privées.
