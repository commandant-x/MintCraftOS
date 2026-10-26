# Quad FPV expérimental — 0.3.0

Importer uniquement `dist/mintcraft-quad-fpv.clipboard.txt`. Ce graphe autonome remplace l'ancien graphe quad : retirer ses contrôleurs avant de réutiliser leurs fréquences. Exporter les groupes MCV1 avant remplacement, importer ces réglages dans les quatre formulaires. Configurer les six touches, le levier physique, chaque paire puissance et le rayon englobant réel. Au sol, passer le levier OFF avant le nouveau prévol. La fermeture de l'éditeur ne coupe pas le calcul serveur.

Ce profil vise quatre hélices modulaires verticales identiques, avec quatre commandes indépendantes. Les hélices petites ou hétérogènes sont refusées par ce profil rapide ; les graphes standard restent disponibles. La validation synthétique de référence utilise 12 voiles par hélice, 256 RPM, masse exposée 32 kg, bras X=±3/Z=±5, inerties diagonales 250/400/230, gravité 11. D'autres dimensions restent configurables et demandent leurs propres essais. Aucun essai Minecraft n'est revendiqué.

Les valeurs initiales deviennent montée 4 m/s, inclinaison 25°, freinage de planification 4 m/s². Les consignes restent modifiables. Le levier autorise le contrôleur ; sa puissance redstone ne fixe jamais le niveau des transmissions. Le contrôleur choisit chaque niveau 0–15 (0 plein régime, 15 arrêt) suivant la poussée demandée. Il estime la montée en régime à partir des commandes émises, sans prétendre lire le régime mécanique réel.

Le contrôle utilise l'attitude quaternion, une référence d'inclinaison amortie et une estimation rapide de vitesse. À faible demande collective, les quatre transmissions identiques utilisent une quantification synchronisée pour éviter une alternance arbitraire entre coins. La demande horizontale est réduite lorsque le modèle prédit une réserve verticale insuffisante. Espace/Shift commandent directement la vitesse verticale ; au relâchement, le maintien reprend près de l'altitude courante.

La correction de sustentation observe l'accélération verticale et la force estimée. Elle peut compenser une tension de corde dont la masse n'apparaît pas dans l'API, sans ajouter de champ utilisateur. Elle n'identifie ni la masse exacte de la charge ni la cause d'une réponse différente. Elle ne garantit pas le rejet d'un pendule arbitraire, d'un choc ou d'une charge supérieure à la poussée disponible.

Une attitude renversée déclenche une tentative de redressement dans le domaine commandable, sans verrouillage exigeant un redémarrage. La mission et la calibration sont mises en pause. Le maintien vertical est physiquement impossible durant certaines parties d'un retournement : conserver de la hauteur et reprendre explicitement la mission après récupération. Aucun lacet du nez n'est ajouté aux quatre hélices fixes.

## Validation reproductible

`tools/test-sputnik-quad-fpv.py` exécute le contrôleur distribué dans le LuaJ extrait du JAR Cosmonautics audité. `tools/sputnik-quad-fpv-twin.lua` est un banc indépendant : corps rigide 6D, pression Sable, réponse des rotors, retard Link et charge ponctuelle suspendue par câble unilatéral. Le contrôleur ne reçoit aucune propriété de la corde. Les empreintes du contrôleur, du banc, des paramètres et des résultats accompagnent chaque rapport.

Ce modèle ne reproduit pas le solveur de joints Minecraft, les collisions, les réseaux de stress, l'effet de sol ou les couples gyroscopiques des hélices. Les temps de réponse sont ceux du banc à 20 Hz, pas une garantie de latence serveur. Les rapports publient les excursions et les échecs, notamment sous retard accru ou inerties différentes. La navigation/calibration partagent les contrats existants mais ne sont pas qualifiées par les seuls essais de stabilisation FPV.

## Résultats de cette livraison

- Référence : 12/12 scénarios réussis. Montée à 90 % de 4 m/s en 0,85 s ; freinage en 4,0 s après la séquence d'avance, contre 6,7 s pour le contrôleur standard soumis aux mêmes consignes dans ce banc.
- Charge de 32 kg sous le véhicule de 32 kg, absente de sa télémétrie de masse : erreur finale verticale 0,005 m ; excursion descendante initiale 1,03 m. La consigne n'est pas remplacée par une recherche de trim.
- Perturbations d'assiette : récupération à 90/150/180° réussie selon les critères du banc. Depuis Y=80, minima respectifs Y=76,72/61,71/69,08. La perte maximale est donc **18,3 m**, et doit être prise au sérieux.
- Stress combiné (inerties divisées par quatre, retard de deux ticks, bruit de position 0,01 m) : **2/4 réussites**. Maintien et petite perturbation passent ; charge oscillante et charge décentrée échouent aux critères d'assiette/vitesse résiduelle. Ce domaine reste non validé.

Les sorties du banc et ses empreintes sont dans `reports/quad-fpv-0.3.0/`. Les valeurs nulles des colonnes de temps signifient « seuil non observé ou non applicable », jamais une réaction instantanée. Les anciens résultats universels qualifient uniquement le contrôleur standard dont l'empreinte reste inchangée.
- Corde de 10 m, charge de 32 kg : maintien et largage passent, mais charge initialement oscillante échoue (oscillation résiduelle d'assiette proche de 20°). Le maintien de charges pendulaires arbitraires reste un travail ouvert ; aucune longueur de corde ne doit être saisie dans le contrôleur.
