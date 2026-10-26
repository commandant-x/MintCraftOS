# Quad FPV expérimental — 0.3.1

Importer uniquement `dist/mintcraft-quad-fpv.clipboard.txt`. Ce graphe autonome remplace l'ancien graphe quad : retirer ses contrôleurs avant de réutiliser leurs fréquences. Exporter les groupes MCV1 avant remplacement, importer ces réglages dans les quatre formulaires. Configurer les six touches, le levier physique, chaque paire puissance et le rayon englobant réel. Au sol, passer le levier OFF avant le nouveau prévol. La fermeture de l'éditeur ne coupe pas le calcul serveur.

Ce profil vise quatre hélices modulaires verticales identiques, avec quatre commandes indépendantes. Les hélices petites ou hétérogènes sont refusées par ce profil rapide ; les graphes standard restent disponibles. La validation synthétique de référence utilise 12 voiles par hélice, 256 RPM, masse exposée 32 kg, bras X=±3/Z=±5, inerties diagonales 250/400/230, gravité 11. D'autres dimensions restent configurables et demandent leurs propres essais. Aucun essai Minecraft n'est revendiqué.

Les valeurs initiales deviennent montée 4 m/s, inclinaison 25°, freinage de planification 4 m/s². Les consignes restent modifiables. Le levier autorise le contrôleur ; sa puissance redstone ne fixe jamais le niveau des transmissions. Le contrôleur choisit chaque niveau 0–15 (0 plein régime, 15 arrêt) suivant la poussée demandée. Il estime la montée en régime à partir des commandes émises, sans prétendre lire le régime mécanique réel.

Le contrôle utilise l'attitude quaternion, une référence d'inclinaison amortie et une estimation rapide de vitesse. À faible demande collective, les quatre transmissions identiques utilisent une quantification synchronisée pour éviter une alternance arbitraire entre coins. La demande horizontale est réduite lorsque le modèle prédit une réserve verticale insuffisante. Espace/Shift commandent directement la vitesse verticale ; au relâchement, le maintien reprend près de l'altitude courante.

La correction de sustentation est désormais un biais **additif**, filtré et borné, obtenu par la différence entre accélération mesurée et réponse estimée des commandes. Il n'y a plus de division par l'accélération verticale augmentée de la gravité : ce dénominateur devenait faible en chute et pouvait amplifier la correction. La correction n'est ni une mesure de masse de la charge, ni un acquittement des moteurs. La cible d'altitude reste inchangée.

L'assiette en maintien utilise un gain proportionnel borné plutôt qu'un gain qui augmente avec le rapport bras/inertie. Le contrôleur garde les corrections de redressement pour les fortes inclinaisons. Le freinage conserve la compensation de débit local après relâchement des touches. Les gains verticaux de maintien sont séparés de la commande directe Espace/Shift. Aucun nouveau paramètre de poids ou de corde n'est demandé.

Une attitude renversée déclenche une tentative de redressement dans le domaine commandable, sans verrouillage exigeant un redémarrage. La mission et la calibration sont mises en pause. Le maintien vertical est physiquement impossible durant certaines parties d'un retournement : conserver de la hauteur et reprendre explicitement la mission après récupération. Aucun lacet du nez n'est ajouté aux quatre hélices fixes.

## Validation reproductible

`tools/test-sputnik-quad-fpv.py` exécute le contrôleur distribué dans le LuaJ extrait du JAR Cosmonautics audité. `tools/sputnik-quad-fpv-twin.lua` est un banc indépendant : corps rigide 6D, pression Sable, réponse des rotors, retard Link et charge ponctuelle suspendue par câble unilatéral. Le contrôleur ne reçoit aucune propriété de la corde. Les empreintes du contrôleur, du banc, des paramètres et des résultats accompagnent chaque rapport.

Ce modèle ne reproduit pas le solveur de joints Minecraft, les collisions, les réseaux de stress, l'effet de sol ou les couples gyroscopiques des hélices. Les temps de réponse sont ceux du banc à 20 Hz, pas une garantie de latence serveur. Les rapports publient les excursions et les échecs, notamment sous retard accru ou inerties différentes. La navigation/calibration partagent les contrats existants mais ne sont pas qualifiées par les seuls essais de stabilisation FPV.

## Régression 0.3.1

La version 0.3.0 a montré un maintien résonant chez l'utilisateur. Le banc précédent, démarré au régime de sustentation et testé principalement avec un retard et une réponse rotor nominaux, ne suffisait pas à exclure cette instabilité. Ses résultats historiques restent consultables dans Git ; ils ne constituent pas une validation de cette correction.

Le banc dure maintenant 60 s et mesure également l'excursion verticale crête-à-crête et la vitesse verticale RMS sur les dix dernières secondes. Les nouveaux scénarios démarrent les rotors à zéro, perturbent simultanément tangage/roulis et introduisent une vitesse de chute. La régression combine inerties divisées par quatre, retard de trois ticks, réponse rotor deux fois plus lente, bruit de position 0,01 m et bruit d'attitude 0,1°. Ces paramètres sont des essais de robustesse, pas des mesures du véhicule du joueur.

Les résultats et limites actualisés sont publiés dans `reports/quad-fpv-0.3.1/`. Le redressement peut toujours perdre de l'altitude ; le banc n'inclut pas les contacts, les contraintes du solveur Minecraft ni une mesure des fréquences reçues sur le véhicule. Il faut vérifier le nouveau maintien dans Minecraft avant de reprendre les essais de vitesse ou de charge.

Résultats 0.3.1 : 13/13 scénarios de référence et 4/4 de résonance passent dans LuaJ. Sur la régression identique, l'ancien contrôleur ne réussit aucun des quatre scénarios avec jusqu'à 22,33 m d'excursion verticale résiduelle, contre au plus 0,50 m pour le correctif. Ces valeurs concernent les dix dernières secondes du banc. Le démarrage à froid peut encore perdre 2,78 m avant stabilisation. La corde longue déjà oscillante reste non validée (2/3 scénarios réussis).
