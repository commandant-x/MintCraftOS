# Essai réel sur copie du monde VENATOR

Ce fixture a été exécuté sur Minecraft 1.21.1 / NeoForge 21.1.264 avec le pack VENATOR fourni. Il est spécifique au grand quad modulaire de ce monde, à son identifiant Sable, ses paires Link et son montage. Il n'est pas un mod générique à placer dans une partie normale.

Il utilise les vrais blocs, les récepteurs Link, les hélices et Rapier/Sable sur un serveur sans interface graphique. Il ne simule pas la physique dans un script externe. Les demandes de touches sont injectées sur leurs fréquences par un nœud Lua de test ; aucune touche physique du Linked Typewriter, interface client ou réseau multijoueur n'est validée par ce procédé.

## Préparation

Fermer le jeu et copier le monde entier dans une **instance serveur distincte**. Conserver l'original intact. Installer NeoForge 21.1.264 et les mods exacts du `.mrpack`, en excluant uniquement ceux déclarés `server: unsupported`, avec les configurations du pack. Le serveur d'essai doit être lié à `127.0.0.1`, sans accès extérieur, et utiliser `level-name=world`. Dans la copie fournie, le grand quad est initialement retenu par le bâton physique ; ce verrou est nécessaire à la préparation de ce fixture.

Ce dépôt ne redistribue ni la sauvegarde ni les mods tiers. Les conditions de licence et le démarrage du serveur restent ceux de Minecraft et de NeoForge.

Compiler dans un répertoire de travail distinct :

```text
python tools/minecraft-world-test/build.py --server CHEMIN_SERVEUR --java-home CHEMIN_JDK21 --work CHEMIN_COMPILATION
```

Le compilateur utilise uniquement les bibliothèques installées du serveur et les JAR imbriqués du pack. Le JAR Cosmonautics original reste intact : le contournement d'un service de compilation Orekit défectueux s'applique seulement à une copie utilisée par javac.

Copier le JAR de test résultant dans `mods/`, puis copier ces deux fichiers de la distribution courante à la racine du serveur :

- `dist/mintcraft-autopilot-quad-fpv.lua` → `mintcraft-controller.lua` ;
- `dist/mintcraft-flight-operations.lua` → `mintcraft-operations.lua`.

Lancer le serveur dans son dossier avec Java 21 et le fichier `unix_args.txt` ou `win_args.txt` généré par NeoForge. Le fixture prépare les quatre groupes, leurs paramètres et leurs fréquences dans la copie. Il réalise OFF/ON physique, préchauffe au trim sous verrou, réarme puis retire le verrou. Il conserve un unique écrivain des commandes moteur. Un nœud séparé émet seulement les six demandes clavier.

## Séquence et limites

Le programme réalise maintien, montée, descente, avance, recul, gauche, droite et diagonale, avec relâchement/freinage entre les impulsions. Les impulsions durent 20 ticks. Q/D sont explicitement configurés en déplacement latéral. Le superviseur reste actif ; un acquittement est demandé après la période de retour au calme et le serveur peut le refuser.

Le fixture enregistre `flight.csv`, `hardware.tsv`, les descripteurs, événements et instantanés du graphe. À la fin, il retient le véhicule avec le bâton physique, remet Enable OFF et exporte les pages du journal serveur avant d'arrêter le serveur. Cette capture du fixture n'est pas une capacité de récupération de l'autopilote. Un dépassement de l'enveloppe de test est compté comme abandon, jamais comme réussite.

Une nouvelle séquence exige une **nouvelle copie de l'original**, sans nœud émetteur de test laissé par la précédente. Ne pas réutiliser cette instance pour une partie ordinaire : ses graphes et commandes ont été modifiés par les essais. L'essai démarre avec des rotors préchauffés ; il ne valide pas un départ avec moteurs froids, une charge suspendue, une nouvelle répartition de masse ou une récupération à l'envers.

Les critères et excursions figurent dans `platforms/sputnik/reports/minecraft-0.4.1/`. Utiliser les résultats de mouvement et la présence de protection : une fin de scénario ou un moteur qui tourne ne suffisent pas à attribuer PASS.

## Campagne de vitesse native (0.4.3)

Compiler le fixture `fleet` avec `build.py`, puis utiliser `fleet/run.py` sur une instance serveur jetable liée à `127.0.0.1`. Les commandes `--speed --timeout 7200` remplacent la séquence normale par la recherche de vitesse et les freinages. `--speed-directions` limite les axes ; `--controller-for CASE=LUA` archive le contrôleur réellement chargé. Conserver `--output` hors du serveur. Exemple après préparation des mods et du JDK 21 :

```sh
python tools/minecraft-world-test/fleet/run.py --server SERVEUR_JETABLE --graph-template platforms/sputnik/dist/mintcraft-hybrid-autopilot.clipboard.txt --probe PROBE_FLEET.jar --java-home JDK21 --output RESULTATS --architectures tri quad hex octo quad-turns --speed --timeout 7200
```

Le ballon vertical exige son contrôleur dédié archivé dans `reports/speed-envelope-0.4.3/balloon-lift/mintcraft-generic-controller.lua` ; le profil ballon général n'est pas équivalent. Le rapport conserve le graphe de départ exact de chaque essai. Le nouveau graphe généré peut avoir un hash différent de ce graphe archivé.

`python tools/report-sputnik-speed.py CAMPAGNE RAPPORT` relit les fenêtres des CSV, vérifie les paliers et les arrêts, et archive les traces en gzip déterministe. Le rapport attend les six constructions et 46 directions de la campagne complète. Les resets avec verrou et téléportation sont exclus des mesures. Voir le [rapport et ses limites](../../platforms/sputnik/reports/speed-envelope-0.4.3/README.md).
