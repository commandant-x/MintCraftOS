# Livraison quad Sputnik 0.3.2

Le TXT complet est `../../dist/mintcraft-quad-fpv.clipboard.txt`. Exporter les groupes MCV1, retirer l’ancien graphe, importer ce TXT, réimporter les réglages et passer physiquement OFF avant prévol. Un seul contrôleur doit utiliser les fréquences moteur. Le défaut d’inclinaison est 20°, montée 4 m/s ; les consignes restent modifiables.

La correction ajoute la priorité collective, les modèles par rotor, la compensation du débit local, un observateur passif de couple et un virage fondé sur la vitesse observée. Les quatre directions de force verticales restent (0,1,0), distinctes de leurs positions. Les modèles ne constituent pas une observation du régime mécanique.

**Campagne native LuaJ : 393 PASS / 159 FAIL / 24 REFUSED** sur 24 montages × 24 mouvements. Référence : 24/24 ; maintien sans touche : 23/23 montages acceptés. Neuf anciennes réussites régressent ; seuls deux montages réussissent tous les mouvements. Le profil reste expérimental. Aucun vol Minecraft n’est revendiqué.

La référence inversée perd 10,39 m avant récupération (6,45 s). Freinages de référence : environ 3,75–5,05 s. À 25°, deux mouvements latéraux échouent ; la valeur initiale de livraison est donc 20°. Les hélices mixtes passent le maintien mais seulement 19/24 mouvements.

Les rapports lourds, courbes, mesures et sources gelées sont séparés du ZIP de vol : [campagne complète](../quad-campaign-0.3.2/README.md), [comparaison et régressions](../quad-campaign-0.3.2/FINDINGS.md), [sensibilité au pas](../quad-campaign-0.3.2/convergence/README.md). Le ZIP de vol reste inférieur à un mégaoctet. [native-checks.log](../quad-campaign-0.3.2/native-checks.log) conserve les vérifications LuaJ, contrats lisible/compact, SNBT/NBT et CODEC natif. Le plan A–F n’est pas entièrement qualifié par cette livraison.
