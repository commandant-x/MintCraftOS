# Capteur de terrain expérimental pour Sputnik

Ce mod optionnel ajoute au graphe Sputnik le nœud `MintCraft / Terrain avant - quadrupede` (`mintcraft_sputnik_obstacle:forward_scan`). Il est compilé et testé avec NeoForge 21.1.264 et les versions de Create: Cosmonautics et Sable du modpack VENATOR de cette expérience. Le jar testé se trouve dans `platforms/sputnik/experiments/spot-quadruped-obstacles/`. Installer le même jar dans les dossiers `mods` du client et du serveur, puis redémarrer. Une sauvegarde qui utilise ce nœud dépend de ce mod.

Le capteur lit les blocs statiques des chunks déjà chargés, sans générer de chunks ni modifier le terrain. Son volume est calibré pour ce robot : en avant du centre du châssis de 11 à 35 blocs, largeur de 28 blocs, hauteur de 15 blocs sous le châssis à 2 au-dessus. `Distance` est la distance au début de ce volume, pas une distance physique aux pieds. Il est réactualisé au plus toutes les cinq ticks. Toute matière non-air y constitue un obstacle : il ne distingue pas la forme de collision, la franchissabilité ou la hauteur utile et ne voit ni entités ni autres corps Sable. Le feuillage suffit à signaler un obstacle. `Possible tree` indique seulement que du bois et des feuilles sont proches : ce n'est pas une identification certaine. `Tree evidence valid` indique si le voisinage recherché était chargé ; il ne garantit pas l'absence d'un arbre. Il n'y a aucune lecture de bloc ajoutée au langage Lua natif : c'est bien un nouveau nœud de mod.

Sorties numériques : `Valid`, `Obstacle`, `Distance`, `Lateral`, `Possible tree`, `Sample tick`, `Tree evidence valid`. Sorties textuelles : `Kind`, `Block`, `Status`. Si une partie du volume est hors des chunks chargés, la pose est invalide ou le nœud n'est pas attaché à un Sputnik dans un sous-monde serveur, `Valid=0` ; le contrôleur doit traiter cet état et les mesures périmées comme un arrêt. Ce dispositif expérimental ne remplace pas un système physique de sécurité et n'assure pas l'évitement.

Pour compiler avec les dépendances du serveur de test :

```sh
python tools/minecraft-world-test/build.py --server CHEMIN_SERVEUR --java-home CHEMIN_JDK_21 --work REPERTOIRE_CONSTRUCTION --fixture sputnik-obstacle-node
```
