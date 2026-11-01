# Essais de séquencement pour bipède et quadrupède

Ces deux TXT Sputnik contiennent chacun **un indicateur expérimental de phases**, sans transmission Link, sans commande moteur et sans qualification de marche. Ils sont destinés à préparer un banc d'essai de jambes ; aucun bipède ou quadrupède physique n'a encore été construit ou testé avec eux.

- [Bipède : TXT à importer](bipede.clipboard.txt)
- [Quadrupède : TXT à importer](quadrupede.clipboard.txt)
- [Sources et banc logiciel](gait-template.lua)

Chaque nœud reçoit `Enable` (0 ou 1), `Forward` (-1 à 1) et `Ticks per phase` (entier de 10 à 200). Après au moins une évaluation valide avec Enable à 0, Enable à 1 autorise le séquencement. Une seule sortie `Leg N swing` vaut 1 à la fois : deux phases pour le bipède, quatre pour le quadrupède. Une demande négative inverse l'ordre, une demande nulle met toutes les phases à 0. Une horloge absente, répétée ou discontinue, ou une entrée invalide, arrête les sorties et impose de repasser Enable à 0. `Walk qualified` reste toujours à 0.

Ces sorties sont des **états abstraits**, pas des angles ni des signaux de puissance : ne pas les raccorder directement à des servos. Une marche réelle nécessite la définition des positions et vitesses articulaires, les contacts au sol, le transfert du poids, la stabilisation, les limites mécaniques et un arrêt adapté au montage. En particulier, lever alternativement un pied d'un bipède ne garantit pas qu'il reste debout.

Le serveur Minecraft du pack contient des servos Aeroworks et les articulations Simulated ; leur compatibilité et la géométrie d'un marcheur restent à tester en physique. Les tests logiciels couvrent les phases avant/arrière, l'arrêt, les défauts d'horloge et le réarmement ; ils ont été exécutés en Lua 5.2 et dans l'interpréteur LuaJ de Cosmonautics. Les deux TXT ont été décodés et sérialisés par les outils Minecraft/Sputnik natifs. Cela ne constitue pas un essai de marche dans Minecraft.

Reproduction : `python3 platforms/sputnik/experiments/walkers/build.py`, puis `lua5.2 platforms/sputnik/experiments/walkers/test-gait.lua`. Ces fichiers sont expérimentaux et ne remplacent pas les contrôleurs de vol livrés dans `dist/`.
