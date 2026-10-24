# Périmètre du portage Sputnik

| Fonction MintCraftOS | Édition Sputnik sans nouveau mod | Limite vérifiée |
| --- | --- | --- |
| Tableau de bord/navigation numérique | Nœud Lua natif et sorties de graphe | Pas le bureau CraftOS |
| Calculs de navigation, altitude, identification, allocation et qualification | 17 modules de développement séparés | Bibliothèque complète non téléversable en un nœud ; données/provenances réelles toujours nécessaires |
| Télémétrie position/vitesse/attitude/masse | API Cosmonautics native | Vitesse du root Sable, pas du bloc tournant ; masse serveur seulement |
| Inertie | API native : diagonale seulement | Pas de tenseur complet ni centre de masse |
| Inventaire moteur | Relevé explicite des IDs/types | Portée dimension ; aucun groupage par proximité |
| Redstone Links | Passerelle explicite, deux items natifs, Enable/STOP | Pas d'acquittement, feedback brûleur ou canal privé |
| Radio | Valeurs numériques canal/code | Cache sans fraîcheur ni authentification ; pas Rednet/NEXUS complet |
| Console de calcul | Bibliothèque locale intégrée | Aucun shell, paquet externe ou `wget` |
| Géométrie 2D/3D réelle, Atlas terrain | Non exposés par les API Lua auditées | Un viewport peut afficher un modèle fourni, pas scanner le vaisseau |
| Autopilote automatique qualifié et réutilisation de modèles | Non activés | UUID, RX brûleurs, provenance mécanique manquent |
| Authentification/permissions OS | Non transposables en barrière serveur | Le joueur capable d'éditer le graphe peut modifier son Lua |
| Browser, CraftTube, Store | Indisponibles dans ce paquet | Pas d'API HTTP de Sputnik officiellement exposée |
| Fichiers, comptes, sauvegardes CC | Conservés dans l'édition CC | Pas de système de fichiers utilisateur Sputnik équivalent |
| Mission détachée sûre/arrêt à fermeture | Non annoncés | Graphe exécuté serveur après fermeture, UI exécutée aussi côté client |

## Sources vérifiées

JAR officiel [26.08.307](https://modrinth.com/mod/create-cosmonatics/version/HuCMavv8),
SHA-256 dans le README. Le code GitHub public à la date de l'audit représente un
ancien éditeur ; le format courant est vérifié dans les classes du JAR :

- `RocketNodes.setupLuaEvaluator` : `_G` persistant par nœud, `input`/`output`,
  capteurs, radio, périphériques, fonctions Link ; aucune injection des API CC.
- `SputnikBlockEntity.getUniverseTime` : ticks d'univers serveur ; `getWorldTime`
  est **day time**, modifiable/gelable, et n'est pas utilisé comme horloge de vol.
- `SputnikBlockEntity.getVelocityVector` : différence des poses du root ×20.
- `WNodeScreen.pasteFromClipboard` : Base64 → UTF-8 SNBT → listes `nodes`/`conns`,
  nouveau UUID au collage, puis synchronisation du graphe au serveur.
- `WNode.save/load` : UUID NBT `[I;...]`, `typeId`, `title`, positions, listes
  d'éléments et `customData.code`. Les retours à la ligne dans le code SNBT sont
  littéraux ; les échappements JSON `\n` ne sont pas utilisés pour ce format.
- `LuaUIBridge` : labels, boutons, champs, sélecteurs d'items et viewport natifs.
  `WButton.wasClicked` est un état local, pas un acquittement réseau de commande.
- `LinkedSignalHandler.tick` : émetteurs virtuels supprimés après 10 ticks sans
  nouvelle émission. Aucun changement de ce handler n'est livré.

La prochaine intégration serveur éventuelle doit apporter un contexte Sable
identifié, les retours physiques et une autorité d'actionnement propre. Elle ne
peut pas être remplacée par des valeurs factices dans un script téléversé.
