# Quad FPV 0.3.1 — correction du maintien résonant

Le signalement utilisateur est une inclinaison diagonale et une oscillation verticale de ±20 blocs sans touche appuyée. Le banc ne prétend pas reproduire exactement ce véhicule. Il reproduit une instabilité importante de l'ancien contrôleur sous retard, erreur de réponse rotor et faible inertie, puis vérifie la correction avec **le même banc et les mêmes paramètres**.

Tous les résultats ci-dessous proviennent du LuaJ réel de Cosmonautics, sur une mécanique indépendante synthétique. Aucun essai Minecraft n'est revendiqué.

| Banc | Réussites | Limite observée |
| --- | --- | --- |
| Référence étendue, dont charge puis avance/freinage | 13/13 | Domaine de référence seulement |
| Régression maintien, démarrage à froid, perturbation diagonale, chute | 4/4 | Excursion verticale résiduelle maximale 0,50 m crête-à-crête |
| Même régression avec le contrôleur publié 0.3.0 | 0/4 | Jusqu'à 22,33 m crête-à-crête résiduels et forte dérive de la hauteur |
| Charge oscillante/décentrée, inerties ×0,25, retard 2 ticks | 4/4 | Aucun essai de joint Minecraft |
| Corde 10 m, charge 32 kg | 2/3 | Le balancement initial reste non validé : jusqu'à 21,71° d'assiette résiduelle |

La régression utilise un véhicule de 32 kg, quatre rotors modulaires de 12 voiles à 256 RPM, bras X=±3/Z=±5, inerties 250/400/230 multipliées par 0,25, retard radio de trois ticks, réponse rotor multipliée par 0,5, bruit de position 0,01 m et bruit d'attitude 0,1°. Le contrôleur ne reçoit ni ce retard réel, ni cette erreur de réponse rotor, ni les paramètres de la corde. Ces variations restent des hypothèses de robustesse, pas des mesures du serveur.

Le banc dure 60 s. L'excursion résiduelle est le maximum moins le minimum de hauteur pendant les **dix dernières secondes** ; elle ne masque pas les transitoires, dont les minima/maxima figurent également dans les CSV. En démarrage à froid de la régression, la hauteur descend de 80 à 77,22 m avant de revenir au maintien. Le redressement de fortes inclinaisons peut encore perdre plus de dix mètres. Les zéros des temps indiquent non observé/non applicable.

La montée atteint 90 % de 4 m/s en 0,90 s sur le banc de référence. Le freinage prend 4,30 s après la séquence d'avance. Le maintien est volontairement moins agressif ; l'autorisation au levier ne fixe toujours pas les niveaux des transmissions.

Le correctif retire la division adaptative par l'accélération verticale augmentée de la gravité. Une correction additive filtrée et bornée compense désormais les écarts de réponse. Le gain d'assiette en maintien ne croît plus avec bras²/inertie. Les commandes de montée et de maintien utilisent des gains distincts. La compensation de freinage suit une intention de déplacement, puis sa décélération ; un mouvement subi du véhicule ne l'active pas. Un écart significatif de réponse réduit ce mode rapide.

Chaque sous-dossier contient empreintes, paramètres, critères, CSV et log. `before/summary.json` référence le commit exact du contrôleur précédent. Les échecs restent visibles. Les sources, l'import natif et la comparaison code lisible/compact sont vérifiés séparément dans `native-checks.log`. Le contrôleur universel et les autres architectures conservent leur code distribué antérieur.
