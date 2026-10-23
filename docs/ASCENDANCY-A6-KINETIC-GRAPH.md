# Ascendancy A.6 — graphe cinétique réel, 0.18.86

Pour revenir depuis 0.18.87 ou plus récent, utiliser le
[retour compatible avec le format 2](COMPACT-SOURCE-0.18.87.md) ;
les commandes d'installateur ancien ci-dessous concernent le format précédent.

Incrément **partiel du lot A**, en lecture seule. Le catalogue de commandes A.2
expose désormais `kineticGraph` : arêtes `sourceId` fournies par Create, racines
correspondant aux hélices du snapshot, RPM signés réels et théoriques, surcharge
et état booléen du clutch. Le signe négatif et `disengaged=false` sont conservés.
Le drapeau `zeroDespiteTheoreticalRotation` décrit uniquement les valeurs
observées ; il n'identifie ni une cause ni une commande responsable.

## Accès et provenance

API de développement existante :
`system.ascendancy.sources.read(actor, "navigation.commands")`.
Le graphe se trouve dans `payload.kineticGraph` quand l'enveloppe est disponible.
`flightd.commands(actor)` fournit également le catalogue à un propriétaire
Navigation autorisé. Ce ne sont pas des commandes du terminal CraftOS.
Les permissions `navigation.assist` **et** `sable.read` restent exigées avant
l'accès au cache. L'état mécanique brut conserve aussi `theoreticalRPM` dans
`equipment`. Aucun nouveau champ n'est transmis à un actionneur.

Le parent fournit l'UUID, le repère `body_plot`, la session, l'instant d'observation
et la validité du snapshot. Le graphe n'a pas un deuxième drapeau de fraîcheur
qui pourrait rester vrai après expiration du parent. Le consommateur doit vérifier
l'enveloppe/parent ; une copie d'un graphe périmé n'est pas une mesure actuelle.
Ces données viennent uniquement du parent chargé, pas d'un monde complet.

Source Java inspectée : `VehicleApi.mechanical`, Bridge 0.2.3, appelle réellement
`KineticBlockEntity.getSpeed()`, `getTheoreticalSpeed()`, `isOverStressed()` et
expose `source` seulement lorsque `hasSource()` le confirme. Aucun rapport de
transmission ni RPM supposé à partir du niveau redstone n'est ajouté.

## Limites physiques importantes

Les arêtes cinétiques sont de véritables relations exposées par Create. Elles
ne prouvent pas quelle fréquence Link commande un clutch ou une transmission.
Le Bridge marque encore `controlBindingsKnown=false`. La proposition existante
de groupage utilise le graphe mécanique puis des récepteurs adjacents comme
candidats ; la proximité seule n'est pas un certificat de câblage.

Ainsi, ce graphe n'associe aucune panne à « gauche » ou « droite », ne déclenche
pas le secours et ne modifie pas la commande. Le superviseur horizontal déjà
qualifié par les réponses mesurées A.1 reste en place. La qualification d'une
surveillance mécanique attribuable nécessite encore la corrélation fraîche des
états physiques avec les commandes effectivement reçues pendant les essais
existants. Aucune fréquence inconnue ne doit être testée pour établir ce lien.

Une chaîne absente, cyclique, trop profonde ou tronquée reste non complète avec
un motif. La terminaison `sourceId=nil` signifie seulement qu'aucune arête source
suivante n'est publiée dans ce snapshot ; elle ne certifie pas l'alimentation ni
la disponibilité d'une poussée. Une surcharge d'un mécanisme non associé n'est
pas transformée en panne du système de maintien vertical.

## Budgets et interface

Index borné à 1 024 mécanismes normalisés ; au plus 16 racines et 64 nœuds publiés,
avec limite de parcours 128. Les nœuds partagés sont dédupliqués. `truncated` et
`pathComplete` signalent explicitement les limites ; le catalogue global n'annonce
pas `complete=true` quand le graphe dépasse le budget. Les chemins omis ne sont
pas considérés sûrs ou inexistants.

Production dans la reconstruction du catalogue existante, au plus une fois par
seconde. Pas d'acquisition nouvelle, de chargement de chunk, d'historique de poses,
de dessin ou de boucle de contrôle supplémentaire. La vue cockpit État A.5
reste identique ; ce nouvel objet est d'abord le contrat de diagnostic utilisé
pour préparer l'attribution mécanique, pas un nouveau panneau RPM complet.

## Compatibilité, tests et retour

Champ facultatif du catalogue, sans migration de configuration ni de rapport.
Aucun changement Java/JAR : Vehicle Bridge 0.2.3 demeure compatible et en lecture
seule. Les données utilisateur et les transactions sont préservées.

Tests : arêtes exactes plutôt que voisins, RPM signés/théoriques, drapeaux,
clutch engagé explicitement faux, source absente/cyclique, chemins partagés,
budgets, expiration du parent et absence d'acquisition. Les suites complètes et
mesures de stockage sont enregistrées dans le statut du projet.
Aucun essai Minecraft effectué.

Après STOP explicite, revenir à 0.18.85 :

```lua
wget run https://raw.githubusercontent.com/commandant-x/MintCraftOS/034a2cf4bd97ef6b6b806c44ef0d91034e2d6344/install.lua
```

Les calibrations, profils et fichiers personnels restent présents. Le lot A
universel et la surveillance RPM attribuée à chaque banque restent en cours.
