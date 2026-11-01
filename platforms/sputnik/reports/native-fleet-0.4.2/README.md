# Flotte native Sputnik — campagne 0.4.2

Campagne du 1er novembre 2026, avec le pack `VENATOR 1.0.0.mrpack` fourni pour cette session. Les véhicules sont construits dans de nouveaux mondes superplats jetables : aucune sauvegarde privée n'est nécessaire. Le banc assemble de vrais sous-niveaux Sable et des hélices Aeronautics ; les commandes passent par les vrais récepteurs Create Link et le Lua du Sputnik. Il ne s'agit pas d'une simulation numérique indépendante. Aucun joueur ni client graphique n'est utilisé.

Le freinage du tricoptère passe de **5/9 à 9/9 phases conformes**. Le réglage spécifique du ballon vertical réussit ses quatre essais disponibles (maintien, montée, descente, choc) ; les cinq commandes horizontales ne font que vérifier le maintien, car ce montage n'a pas de propulsion horizontale. Aucun profil n'est globalement qualifié.

[Vue d'ensemble](overview.png) · [PDF](overview.pdf) · [Empreintes et résultats structurés](validation.json)

| Construction | Masse native | Résultat strict | TXT configuré | Mesures |
|---|---:|---|---|---|
| Tricoptère Y corrigé | 111,5 kg | **9/9** ; référence précédente 5/9 | [Tricoptère](tricopter.clipboard.txt) | [Rapport](tri-final/results.json), [courbes](tri-final/movements.pdf) |
| Quad standard, quatre sustentations | 126,75 kg | 5/9 ; recul, latéral et diagonale encore hors critère | [Quad standard](quadcopter.clipboard.txt) | [Rapport](quad/results.json), [courbes](quad/movements.pdf) |
| Quad avec deux propulsions réversibles | 134,75 kg | 7/9 ; diagonale et choc échouent | [Quad propulsé](quad-drive.clipboard.txt) | [Rapport](quad-drive/results.json), [courbes](quad-drive/movements.pdf) |
| Hexacoptère | 166,25 kg | 6/9 ; recul et latéral hors critère | [Hexacoptère](hexacopter.clipboard.txt) | [Rapport](hex/results.json), [courbes](hex/movements.pdf) |
| Octocoptère | 188,25 kg | 7/9 ; latéral hors critère | [Octocoptère](octocopter.clipboard.txt) | [Rapport](octo/results.json), [courbes](octo/movements.pdf) |
| Ballon vertical réglé | 261,25 kg | **4/4 essais disponibles**, plus cinq maintiens seuls ; aucune commande horizontale | [Ballon vertical](balloon-vertical.clipboard.txt) | [Rapport](balloon-final/results.json), [courbes](balloon-final/movements.pdf) |

Ces TXT correspondent exactement aux géométries et fréquences des véhicules du banc. Ils contiennent sept nœuds et 34 connexions, des identifiants distincts et aucun émetteur de touches du banc. Les caches des entrées/sorties sont vidés. Le vrai parseur SNBT, la sérialisation binaire NBT et le CODEC Sputnik ont vérifié les six fichiers. Ils ne constituent pas une configuration universelle pour un autre véhicule. Une construction réussie ou le message `HOLDING` ne prouve pas un vol stable.

## Correctifs et comparaison

Le contrôleur universel anticipe désormais la vitesse pendant le freinage des montages à trois groupes sans propulsion auxiliaire avec un terme d'accélération de 1,2 s, contre 0,4 s auparavant. Sur le même constructeur et la même séquence, le recul et les déplacements latéraux cessent d'entretenir un second pic de vitesse. Le code compact du résultat 9/9 est exactement celui livré dans `dist/mintcraft-autopilot-control.lua`. Un essai intermédiaire à 0,8 s réduisait le rebond sans réussir tous les critères. Appliquer ce changement à toutes les architectures avait dégradé un essai synthétique à hélices hétérogènes ; cette variante globale a été rejetée. Cinq profils de référence ont ensuite produit les mêmes commandes et états numériques qu'au commit `de8f704` sur 500 mises à jour chacun (textes de diagnostic exclus). Le nouveau tricoptère a son essai réel distinct ; ces comparaisons ne remplacent pas une qualification de toutes les masses.

Le ballon initial échouait à ses neuf vérifications de maintien final. L'instrumentation montre une réponse effective du gaz de plusieurs secondes, dépendante de l'état : [estimation et limites](balloon-response.json). Le pilote spécifique livré dans son TXT utilise une demande de vitesse verticale plus progressive, davantage d'amortissement de vitesse/accélération et une intégration réduite. Le premier candidat stabilisait le maintien, mais pas la montée/descente dans la fenêtre stricte ; le second réussit les quatre essais disponibles et les maintiens des cinq commandes indisponibles. Les [sources lisibles](sources/balloon-trial2-readable.lua) et [compactes](sources/balloon-trial2.lua) correspondent exactement au code essayé. Ce réglage est livré séparément, sans remplacer le contrôleur générique des ballons propulsés. Aucun capteur de gaz ni autotuning universel n'est ajouté au Lua public.

Le premier démarrage du quad à quatre hélices a révélé une vérification du banc qui attendait encore six moteurs. [L'erreur et les événements sont conservés](quad-first-attempt.json). Elle a été corrigée avant une nouvelle construction et une séquence complète : ce refus du banc ne compte ni comme vol ni comme échec physique du pilote.

Un essai supplémentaire du pilote FPV existant sur ce nouveau quad n’est pas retenu : une seule phase est PASS, la montée/descente et les déplacements ne respectent pas les critères et le choc déclenche la protection. [Mesures complètes](quad-fpv-not-selected/results.json), [courbes](quad-fpv-not-selected/movements.pdf). Le TXT standard reste celui du monde livré ; aucun résultat de ce nouvel essai ne qualifie le profil FPV pour cette géométrie.

## Mondes construits

Les copies destinées à l'ouverture ont été rechargées dans le vrai serveur Minecraft. Leurs graphes sont remplacés par les sept nœuds de production, les émetteurs de touches automatiques sont retirés, les sources créatives sont mises à **0 RPM**, les leviers à OFF et le verrou du Physics Staff est conservé. [Vérifications](prepared-worlds). Cette préparation n'est pas un nouveau vol. [Télécharger les six mondes et leurs TXT](../../worlds/mintcraft-sputnik-fleet-0.4.2.zip). Les mondes téléchargeables accompagnent la livraison ; les mesures de vol brutes sont conservées séparément.

Restaurer les sources mesurées à 256 RPM, garder le véhicule verrouillé et effectuer la vérification mécanique avant un nouvel essai. Le modèle reste déclaré ; les coordonnées et fréquences sont propres à chaque monde. Ne pas réunir ces véhicules dans un même monde avec leurs fréquences communes.

## Vérification logicielle

Compilation Java du banc contre les bibliothèques et mods installés, suite Python du rapport (9 tests), construction déterministe, budgets UTF modifié, tests LuaJ du JAR Cosmonautics, régressions numériques de référence, contrôles de persistance des widgets et vérification native des six TXT. Les journaux et sources de chaque variante sont dans [sources](sources). Les essais numériques et les vols Minecraft sont deux ensembles de preuves distincts. Les résultats FAIL restent publiés.


## Protocole

Chaque cas démarre dans une nouvelle JVM et un nouveau monde. La géométrie, les voiles assemblées, la masse et les fréquences sont relevées par l'instrumentation Java du banc ; cette préparation ne fournit pas un scanner au Lua distribué. Le contrôleur reste le seul auteur des commandes moteur après la vérification préalable de chaque arbre à 80 RPM. L'émetteur temporaire de vérification est retiré avant l'armement.

La séquence enchaîne maintien, montée, descente, avance, recul, gauche, droite, diagonale puis impulsion latérale de 5 m/s. Les touches sont injectées sur les canaux Link, pas frappées sur un clavier physique. Chaque déplacement dure 60 ticks. Les phases de déplacement durent 400 ticks ; le choc est observé pendant 800 ticks.

Un résultat PASS exige le mouvement demandé lorsqu'il est disponible, puis 200 observations consécutives fraîches avec erreur d'altitude ≤1 m, vitesse verticale ≤0,1 m/s, vitesse horizontale ≤0,2 m/s et inclinaison ≤5°. Une protection mémorisée empêche PASS. Les transitoires et l'état d'entrée de chaque phase restent publiés. Les phases ne sont pas des essais indépendants. Une commande latérale ne peut pas être déclarée réussie sur la seule base d'un maintien sans déplacement.

## Périmètre

Les constructions ajoutées au banc sont le quad sans propulsion auxiliaire, l'hexacoptère et l'octocoptère. Tricoptère, quad à propulsion différentielle et ballon vertical sont réévalués. Les fichiers de chaque cas identifient précisément leur contrôleur et leur constructeur : des nombres de versions identiques ne suffisent pas à prouver un code identique.

Le TXT hélicoptère existant est un graphe de contrôle à configurer ; cette campagne ne construit ni ne qualifie un hélicoptère complet. Aucun TXT avion ou V22 n'existait dans le dépôt initial. Le vol sur ailes, les gouvernes articulées, le décollage d'un avion et la transition d'un V22 restent à développer et à tester. Les servos Aeroworks et les pivots Simulated sont présents dans le pack, mais le modèle actuel de poussée fixe et de démarrage en sustentation ne constitue pas leur contrôleur de transition. Un graphe hybride renommé n'est pas livré comme substitut.

Les mondes d'essai sont indépendants et utilisent des fréquences communes. Ne pas réunir les véhicules dans un même monde sans réattribuer les fréquences physiques et celles des graphes. Aucun profil n'est globalement qualifié ; charge suspendue, joueur embarqué, vent, collisions et atterrissage ne sont pas couverts.
