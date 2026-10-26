# Quad FPV expérimental — 0.3.2

Importer uniquement `dist/mintcraft-quad-fpv.clipboard.txt`. Ce graphe autonome remplace l'ancien graphe quad : exporter les groupes MCV1, puis retirer les anciens contrôleurs avant de réutiliser leurs fréquences. Réimporter les groupes dans les quatre formulaires. Configurer les six touches, le levier physique, chaque paire puissance et le rayon englobant réel. Au sol, passer le levier OFF avant le nouveau prévol. La fermeture de l'éditeur ne coupe pas le calcul serveur.

Le profil accepte quatre hélices verticales, petites ou modulaires, avec quatre commandes indépendantes. Chaque rotor garde son propre type, nombre de voiles, régime source, position et modèle de réponse. Une acceptation de configuration ne certifie pas sa stabilité : les domaines réussis et échoués sont publiés dans [la campagne complète](reports/quad-campaign-0.3.2/README.md). Aucun essai Minecraft n'est revendiqué.

La référence synthétique utilise 12 voiles par hélice, 256 RPM, masse exposée 32 kg, bras X=±3/Z=±5, inerties diagonales 250/400/230 et gravité 11. Les positions sont relatives au centre de masse déclaré ; la direction de force de chaque rotor vertical vaut **X=0, Y=1, Z=0**, indépendamment de sa position. Le Lua ne scanne ni les voiles ni le centre de masse.

Les valeurs initiales sont montée 4 m/s, inclinaison 20° et freinage de planification 4 m/s². Elles restent modifiables. Le levier autorise le contrôleur ; sa puissance redstone ne fixe jamais le niveau des transmissions. Le contrôleur choisit chaque niveau 0–15 (0 plein régime, 15 arrêt) suivant la poussée demandée. Il estime la montée en régime à partir des commandes émises, sans prétendre lire le régime mécanique réel.

## Corrections 0.3.2

L'allocation conserve d'abord la sustentation collective réalisable et répartit les corrections de tangage/roulis avec le reste de l'autorité disponible. Une demande d'assiette impossible ne peut plus consommer arbitrairement cette sustentation. Lors d'une récupération importante, les moments reprennent la priorité : le maintien d'altitude n'est alors pas garanti.

La référence d'inclinaison tient compte du temps de réponse du rotor le plus lent. Le modèle de poussée et sa compensation utilisent séparément le débit local de chaque hélice. Le virage de trajectoire part de la vitesse réellement observée et réduit sa courbure selon la réponse mécanique estimée. Il ne fait pas tourner le nez d'un quad dépourvu d'autorité de lacet. Aucun plafond de vitesse n'est ajouté.

La correction verticale reste un biais additif borné issu de l'écart entre accélération mesurée et réponse estimée. Un observateur passif de couple corrige aussi le maintien lorsqu'une différence de poussée ou un centre de masse décalé produit une accélération angulaire persistante. Ces corrections ne mesurent pas le poids d'une charge suspendue ni la cause d'une panne. Elles ne changent pas la cible d'altitude et n'injectent pas d'impulsions de calibration.

Espace/Shift demandent une vitesse verticale ; le freinage vertical reste actif après relâchement. Cette réponse rapide est suspendue durant le redressement pour éviter qu'elle combatte la récupération d'assiette. Les quatre transmissions identiques gardent une quantification couplée pour éviter une alternance arbitraire entre coins. Les rotors différents sont alloués suivant leurs propres capacités.

L'attitude et les changements de repère utilisent des quaternions. L'API d'angles ne fournit pas un vrai gyroscope ; la vitesse angulaire est estimée entre deux poses. Un saut presque égal à un demi-tour rend cette estimation ambiguë : elle est réacquise sans créer une vitesse angulaire fictive. Une inversion déclenche une tentative de redressement sans verrouillage exigeant un redémarrage, mais avec une perte d'altitude possible. Mission et calibration sont mises en pause, puis reprises explicitement.

Les erreurs de descripteur indiquent désormais le numéro du moteur et renvoient au formulaire au lieu du seul message `Descriptor schema/field count`. Les consignes restent séparées du montage figé en vol ; les autres architectures et le contrôleur standard sont inchangés.

## Validation et limites

Les contrats lisible/compact, les modèles par rotor, la conservation du collectif sous demande de couple impossible, les consignes sans réinitialisation et le rejet des observations périmées sont vérifiés dans le LuaJ du JAR Cosmonautics audité. Les imports passent par SNBT, sérialisation NBT binaire et CODEC natif ; chaque nœud reste sous 60 000 octets UTF modifié.

Le banc indépendant exécute 24 mouvements sur 24 géométries et motorisations. Il conserve chaque trace et les critères d'échec, notamment sous faibles inerties, retard radio, hélices hétérogènes et charge pendulaire. Voir [les résultats et sources gelées](reports/quad-campaign-0.3.2/README.md) et [le résumé de livraison](reports/quad-fpv-0.3.2/README.md). Les critères ne sont pas relâchés pour le correctif.

Ce modèle ne reproduit pas le solveur de joints Minecraft, les collisions, les réseaux de stress, l'effet de sol ou les couples gyroscopiques des hélices. Les 20 Hz de calcul simulé ne garantissent pas la latence du serveur. La navigation et la calibration ne sont pas qualifiées par les seuls essais de stabilisation. Les profils en échec restent expérimentaux ; conserver une altitude suffisante pour les essais progressifs dans Minecraft.
