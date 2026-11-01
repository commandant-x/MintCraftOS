# Chocs physiques et captures Minecraft

Ces outils complètent le fixture VENATOR décrit dans le [README parent](../README.md). Ils nécessitent le monde privé fourni, le grand quad retenu au bâton physique, et les versions exactes du pack. Ils sont réservés à une instance jetable, liée à `127.0.0.1`. Le monde original doit rester séparé et intact.

## Compilation

Utiliser des répertoires de compilation distincts. Le serveur installé suffit pour le fixture de chocs :

```text
python tools/minecraft-world-test/build.py --fixture shocks --server SERVEUR --java-home JDK21 --work COMPILATION_CHOCS
```

Le spectateur exige aussi les bibliothèques d'un client NeoForge installé :

```text
python tools/minecraft-world-test/build.py --fixture viewer --server SERVEUR --client CLIENT --java-home JDK21 --work COMPILATION_SPECTATEUR
```

Installer le premier JAR uniquement dans le serveur de test et le second uniquement dans le client. Les fixtures de mouvements et de chocs partagent le même identifiant de mod : ils ne doivent pas coexister. Le contrôleur et le superviseur Lua restent ceux copiés à la racine du serveur, comme dans le protocole parent.

Le spectateur se connecte à `127.0.0.1:25585`. Lancer le client avec le nom de test `MintObserver` (12 caractères), un profil de test hors ligne et ce port de serveur. Ne pas réutiliser l'identité d'un joueur. Le serveur le place en spectateur, sans contact avec le véhicule, et déplace seulement sa caméra. Le fixture n'automatise pas l'authentification d'un compte Minecraft.

## Exécution et impulsions

```text
python tools/minecraft-world-test/shocks/run.py --server SERVEUR --original-world ORIGINAL_INTACT --probe COMPILATION_CHOCS/mintcraft-test-probe.jar --java-home JDK21 --output RESULTATS --wait-for-viewer --screenshots CLIENT/screenshots
```

Le programme conserve le monde de travail précédent dans le dossier du cas, copie à nouveau l'original et lance un nouveau serveur par cas. Prévoir de l'espace disque ; ces mondes privés ne doivent pas être publiés. Sans client graphique, retirer `--wait-for-viewer` et `--screenshots` : les essais restent physiques mais ne produisent pas de captures du jeu. Le serveur hors ligne doit rester inaccessible depuis l'extérieur.

Chaque cas passe OFF/ON, préchauffe sous verrou, réarme et libère le véhicule au tick 320. Le choc arrive au tick 800, après 24 secondes de vol libre. Le pilote garde l'unique propriété des quatre fréquences moteur. Le fixture n'émet aucune commande de mouvement pendant ces essais et n'acquitte pas les protections.

| Cas | Variation de vitesse demandée dans le monde | Variation de vitesse angulaire demandée dans le repère corps |
| --- | --- | --- |
| side5 | (5, 0, 0) m/s | zéro |
| side12 | (12, 0, 0) m/s | zéro |
| down8 | (0, −8, 0) m/s | zéro |
| up8 | (0, 8, 0) m/s | zéro |
| roll2 | zéro | Z : 2 rad/s |
| pitch2 | zéro | X : 2 rad/s |
| combined | (7, −6, 3) m/s | X et Z : 1,5 rad/s |
| inversion | zéro | Z : 6 rad/s |

Les impulsions sont `J = masse × Δv` et `L = rotation_corps→monde × inertie_corps × Δω`. Elles sont appliquées une seule fois par `RigidBodyHandle.applyLinearAndAngularImpulse`. La pose et la vitesse ne sont pas réécrites pour obtenir le mouvement. Ce sont des perturbations du solveur natif ; cela ne teste ni explosion, ni collision déformante, ni perte de blocs.

La réponse libre est observée jusqu'au tick 1800. Une altitude sous 80 m, une sortie de ±250 m en X ou Z depuis le départ, ou un contrôleur désactivé déclenchent la capture par le bâton physique et Enable OFF. Cette intervention du banc compte comme ABORT. Ce sont des bornes du test, pas de nouvelles limites du Lua distribué. Aucun seuil d'angle ne met fin à l'essai. L'absence de choc enregistré ou un délai de lancement dépassé ne qualifient jamais un profil.

## Mesures et rendu

`flight.csv` contient positions et angles YXZ en degrés, vitesses linéaires en m/s, consigne d'altitude, Active, RPM absolus réels et puissances reçues par les quatre Links. **wx/wy/wz sont les dérivées d'Euler exposées par Sputnik, en degrés/s**, pas la vitesse angulaire native dans le monde. `protection` indique l'arrêt horizontal demandé par le superviseur.

Le spectateur utilise `Screenshot.grab` toutes les 40 mises à jour client, avec un plafond de 600 images par lancement. Les fichiers `observer-EPOCH_MS.png` sont des captures du framebuffer Minecraft. Un index par heure les associe au passage ; ce n'est pas une synchronisation exacte au tick serveur. Le rendu et la physique peuvent avoir des retards différents. Fermer et relancer le client si le pack se bloque pendant une reconnexion ; conserver ce défaut dans le compte rendu. Ne pas présenter une fenêtre de chargement comme une capture du choc.

Pour des captures X11 plus rapprochées autour du choc, le client doit être visible sur l'affichage indiqué :

```text
python tools/minecraft-world-test/shocks/capture-x11.py --active RESULTATS/active-run.json --server SERVEUR --output CAPTURES --display :99 --size 1280x720
```

Cet outil utilise `ffmpeg x11grab` et conserve le tick lu **avant** la capture, ainsi que les heures de début et de fin de celle-ci. La latence de capture et d'interpolation client reste présente ; ce tick n'est pas un horodatage exact de l'image rendue. Arrêter l'outil après la campagne avec Ctrl+C. Les captures publiées sont copiées sans recadrage ni retouche.

## Analyse

```text
python tools/report-sputnik-shocks.py --runs RESULTATS --output RAPPORT
python tools/test-sputnik-shock-report.py
```

Le rapport conserve les pointes pendant le choc, le retour au calme, la protection et les abandons. Il vérifie les 200 observations fraîches avant le choc et les 200 dernières après celui-ci : erreur d'altitude ≤ 1 m, |Vy| ≤ 0,1 m/s, vitesse horizontale ≤ 0,2 m/s, inclinaison totale ≤ 5°, Active=1. Un PASS exige aussi une perturbation observée, la fin du scénario, la consigne conservée et aucune protection encore active. Un maintien avec protection est PROTECTED, même s'il est physiquement stable. Les échantillons après capture ne comptent pas comme récupération. L'échantillon du franchissement d'enveloppe, enregistré avant la capture, reste inclus dans les pointes d'un ABORT.

Le premier intervalle calme d'une seconde et le début de la stabilité conservée jusqu'à la fin sont deux mesures différentes. Le temps est celui des ticks de jeu divisés par 20, pas une mesure des performances en temps réel. Les courbes et le PDF sont des tracés des CSV, pas des images Minecraft générées.
