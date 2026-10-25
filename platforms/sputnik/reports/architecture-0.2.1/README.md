# Sputnik 0.2.1 — graphes séparés

Le contrôleur de vol est identique octet pour octet à celui de la 0.2.0. Cette livraison réduit le graphe affiché et les ports inutilisés ; elle ne modifie pas les gains de stabilisation et ne prétend pas mesurer les FPS dans Minecraft.

| Graphe | Groupes | Nœuds | Connexions | Widgets construits au premier affichage (fixture LuaJ) |
| --- | ---: | ---: | ---: | ---: |
| Quad | 4 | 10 | 29 | 308 |
| Ballon | 4 | 10 | 29 | 308 |
| Venator | 6 | 12 | 35 | 424 |
| Hélicoptère | 4 | 10 | 29 | 308 |
| Universel avancé conservé | 8 formulaires | 16 | 46 | non mesuré |

Les variantes omettent le viewport cartographique et le second afficheur. L’agrégateur expose seulement 8 entrées de groupes/observations (12 pour le Venator), au lieu de 64. Les architectures et modèles initiaux sont préchargés ; aucune fréquence moteur n’est renseignée et les groupes restent désactivés.

Validation : exécution des scripts générés dans LuaJ réel de Cosmonautics ; profils et rôles initiaux corrects, banques Venator à deux membres, un seul émetteur, démarrage Enable déjà haut refusé, passage physique OFF, consigne d’altitude acceptée sans réinitialiser l’estimateur. Les fixtures correspondent exactement aux TXT livrés. Les 28 imports sont vérifiés par le parseur SNBT Minecraft, le format NBT binaire et le codec réel Sputnik. La suite existante et les six scénarios de régression du contrôleur commun passent également.

Les résultats de vol indépendants de la 0.2.0 restent dans [universal-0.2.0](../universal-0.2.0/README.md), avec leurs échecs conservés. Ce contrôle d’intégrité ne qualifie pas les nouveaux graphes dans un monde Minecraft.

Importer **un seul** TXT et retirer l’ancien graphe au sol, moteurs coupés indépendamment. Coller la variante par-dessus l’ancienne conserverait les anciens formulaires et pourrait créer deux émetteurs concurrents. Pour éviter de ressaisir les fréquences, exporter les descripteurs depuis l’ancien agrégateur puis les importer dans le nouveau ; voir [le guide](../../README.md).
