# Commande Sputnik du quadrupède

Le monde livré contient déjà le graphe Sputnik à deux nœuds et les treize récepteurs Create Redstone Link. Le presse-papiers [spot-quadruped-wireless.clipboard.txt](spot-quadruped-wireless.clipboard.txt) contient ce graphe ; [gait-wireless.lua](gait-wireless.lua) est le code de commande et [operator-node.lua](operator-node.lua) construit les cases de l'interface.

Pour l'essai, régler le moteur créatif sur 4 tr/min après avoir vérifié que les douze récepteurs d'embrayage reçoivent 15, puis cocher « Armer les commandes redstone » et « Lancer les huit mouvements ». La séquence exécute deux passages arrière gauche, avant droite, avant gauche, arrière droite. Décocher la seconde case avant de la relancer ; décocher la première désarme la séquence. À la fin, arrêter aussi le moteur manuellement. Le monde est enregistré moteur arrêté et cases décochées.

Le graphe a été exercé dans Minecraft par un fixture qui changeait les cases de l'interface : Sputnik commandait les récepteurs et les mécanismes réels. La marche utilise des durées prédéfinies sans retour d'angle ni de contact ; elle a été essayée sur sol plat sans joueur embarqué. Un seul axe tourne à la fois et le sens est commun.

Les douze embrayages sont coupés quand leur récepteur reçoit 15 et engagés à 0. **Une perte de liaison peut donc engager un embrayage : ce montage ne constitue pas un arrêt de sécurité sur perte de signal.** Garder le moteur arrêté avant toute vérification ou modification des liaisons.

Les fréquences des récepteurs utilisent toutes un bloc de netherite comme second objet :

| Patte | Roulis | Hanche | Genou |
| --- | --- | --- | --- |
| Avant gauche | laine blanche | orange | magenta |
| Avant droite | bleu clair | jaune | vert clair |
| Arrière gauche | rose | grise | gris clair |
| Arrière droite | cyan | violette | bleue |

Le changement de sens commun utilise la laine marron et le bloc de netherite. Les sources et tests Lua sont dans ce dossier ; `spot-quadruped-gait.clipboard.txt` est l'ancien graphe sans liaisons radio.
