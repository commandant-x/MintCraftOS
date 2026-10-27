> Livraison 0.4.0 : [montage unifié, journal, protection et migration](OPERATIONS.md). Les limites physiques et les échecs des campagnes restent applicables.

# Quad FPV expérimental — 0.4.0

Importer uniquement `dist/mintcraft-quad-fpv.clipboard.txt`. Ce graphe autonome remplace l'ancien graphe quad : exporter les groupes MCV1, puis retirer les anciens contrôleurs avant de réutiliser leurs fréquences. Réimporter les groupes dans le formulaire de montage unique, en choisissant leur numéro. Configurer les six touches, le levier physique, chaque paire puissance et le rayon englobant réel. Au sol, passer le levier OFF avant le nouveau prévol. La fermeture de l'éditeur ne coupe pas le calcul serveur.

Le profil accepte quatre hélices verticales, petites ou modulaires, avec quatre commandes indépendantes. Chaque rotor garde son propre type, nombre de voiles, régime source, position et modèle de réponse. Une acceptation de configuration ne certifie pas sa stabilité : les domaines réussis et échoués sont publiés dans [la campagne complète](reports/quad-campaign-0.3.5/README.md). Aucun essai Minecraft n'est revendiqué.

La référence synthétique utilise 12 voiles par hélice, 256 RPM, masse exposée 32 kg, bras X=±3/Z=±5, inerties diagonales 250/400/230 et gravité 11. Les positions sont relatives au centre de masse déclaré ; la direction de force de chaque rotor vertical vaut **X=0, Y=1, Z=0**, indépendamment de sa position. Le Lua ne scanne ni les voiles ni le centre de masse.

Les valeurs initiales sont montée 4 m/s, inclinaison 20° et freinage de planification 4 m/s². Elles restent modifiables. Le levier autorise le contrôleur ; sa puissance redstone ne fixe jamais le niveau des transmissions. Le contrôleur choisit chaque niveau 0–15 (0 plein régime, 15 arrêt) suivant la poussée demandée. Il estime la montée en régime à partir des commandes émises, sans prétendre lire le régime mécanique réel.

## Correction 0.3.5 : maintien avec charge suspendue

Le retour horizontal au maintien tient compte de l’effort vertical extérieur estimé. Cela évite de contre-braquer aussi fortement à chaque passage d’une charge qui balance. Le contrôleur peut apprendre cet effort pendant les mouvements angulaires modérés : l’ancien contrôle de calme gelait l’apprentissage précisément durant certaines oscillations. Les filtres et bornes d’effort restent actifs, et l’apprentissage est suspendu pendant le redressement ou une forte inclinaison.

Le freinage vertical renforcé est utilisé pour une commande verticale ou quand l’effort extérieur estimé dépasse 10 % de la gravité. Le gain précédent est conservé au maintien sans cet effort, après qu’un prototype toujours renforcé a montré une régression en translation latérale. La consigne de vitesse n’augmente pas et les demandes manuelles restent les mêmes. Aucun plafond de vitesse horizontal ni entrée de longueur de corde/poids suspendu n’est ajouté. L’effort estimé n’identifie pas la masse ou la cause physique.

Le [banc avec câble](reports/quad-load-0.3.5/README.md) vérifie aussi que la charge se calme, et pas seulement le châssis. Il couvre maintien, freinage, diagonale, montée, descente et cycle vertical. Les échecs restent publiés. Le modèle de câble n’est pas le solveur de joints Minecraft et ne qualifie pas un assemblage à plusieurs cordes ou une charge étendue.

## Correction 0.3.4 : déplacement du centre de masse

Un changement de masse ou de répartition ne réinitialise plus l’équilibrage : les accélérations angulaires réellement observées corrigent les bras de levier effectifs utilisés pour répartir la poussée. L’estimation est normalisée par la poussée, puis transportée lors des changements de masse et d’inertie. Elle reste une estimation du déséquilibre, sans lecture fictive du centre de masse. L’altitude demandée, le modèle opérateur et les fréquences ne changent pas ; aucun essai actif ni nouveau champ n’est requis en vol.

L’ancien biais attendait une assiette déjà calme et était borné à ±2 rad/s² : un fort décentrage pouvait empêcher son apprentissage. Le nouveau calcul apprend pendant la réponse au déséquilibre et cherche une répartition bornée dans tout le support des quatre hélices. Il conserve le résidu de modulation pendant l’adaptation. Lorsque l’équilibre estimé sort du support, il conserve le dernier équilibre exploitable et suspend la demande horizontale ; cela ne garantit pas le maintien d’une charge physiquement hors support.

Les [72 essais comparés](reports/quad-com-0.3.4/README.md) comprennent maintien et manœuvres, centre déplacé à masse constante, charge ajoutée/retirée, hélices différentes et retard. Les succès COM passent de 6/36 à 15/36. Pour l’ajout puis retrait d’une charge éloignée, l’excursion verticale maximale au maintien passe de 54,25 m à 0,62 m. Des oscillations résiduelles et échecs restent présents, notamment avec retard et dans certains changements de côté ; aucun maintien universel n’est annoncé. Les critères COM vérifient chaque épisode, distinctement des anciens critères complets conservés dans le rapport.

## Correction 0.3.3 : petites corrections conservées à 256 RPM

Le régime mécanique reste **256 RPM** et les transmissions restent sur leurs niveaux 0–15. Aucune nouvelle valeur de poids, de rapport ou de voiles n'est requise par cette correction. Le TXT conserve les mêmes formulaires et commandes.

L'ancien raccourci de maintien regroupait les demandes presque égales (`écart < 0,08 niveau`), imposait une sortie commune et effaçait le résidu de couple. Une petite correction nécessaire pouvait donc disparaître, puis revenir brutalement après accumulation d'erreur d'assiette. Ce raccourci est supprimé : un même quantificateur couplé traite les grandes et petites demandes et conserve leur résidu. Les moteurs peuvent recevoir des niveaux différents à un instant donné pour représenter un faible couple moyen ; cela ne signifie pas une augmentation du régime source ni une commande analogique supplémentaire.

Le test de régression mesure la poussée et le couple moyens issus des RPM réellement demandés par les sorties entières, avec un très faible couple demandé dans les deux sens. Il échoue sur le contrôleur 0.3.2 et réussit sur le correctif. Le banc natif vérifie également le départ incliné, le maintien et les transitions, en plus des anciens critères finaux. Les sources et traces sont conservées dans [la régression à régime fixe](reports/quad-pwm-0.3.3/README.md) et [la campagne complète](reports/quad-campaign-0.3.5/README.md).

Les gains, modèles de poussée, filtres, capteurs, seuils de récupération et contrôleurs des autres architectures ne changent pas. Aucun essai Minecraft n'est revendiqué.

## Contrôle conservé depuis 0.3.2

L'allocation conserve d'abord la sustentation collective réalisable et répartit les corrections de tangage/roulis avec le reste de l'autorité disponible. Une demande d'assiette impossible ne peut plus consommer arbitrairement cette sustentation. Lors d'une récupération importante, les moments reprennent la priorité : le maintien d'altitude n'est alors pas garanti.

La référence d'inclinaison tient compte du temps de réponse du rotor le plus lent. Le modèle de poussée et sa compensation utilisent séparément le débit local de chaque hélice. Le virage de trajectoire part de la vitesse réellement observée et réduit sa courbure selon la réponse mécanique estimée. Il ne fait pas tourner le nez d'un quad dépourvu d'autorité de lacet. Aucun plafond de vitesse n'est ajouté.

La correction verticale reste un biais additif borné issu de l'écart entre accélération mesurée et réponse estimée. L’observateur de couple décrit ci-dessus adapte la répartition lorsqu’une différence de poussée ou un centre de masse décalé produit une accélération angulaire. Ces corrections ne mesurent pas le poids d'une charge suspendue ni la cause d'une panne. Elles ne changent pas la cible d'altitude et n'injectent pas d'impulsions de calibration.

Espace/Shift demandent une vitesse verticale ; le freinage vertical reste actif après relâchement. Cette réponse rapide est suspendue durant le redressement pour éviter qu'elle combatte la récupération d'assiette. Les quatre transmissions gardent une quantification couplée qui conserve aussi les petites corrections différentielles. Les rotors différents sont alloués suivant leurs propres capacités.

L'attitude et les changements de repère utilisent des quaternions. L'API d'angles ne fournit pas un vrai gyroscope ; la vitesse angulaire est estimée entre deux poses. Un saut presque égal à un demi-tour rend cette estimation ambiguë : elle est réacquise sans créer une vitesse angulaire fictive. Une inversion déclenche une tentative de redressement sans verrouillage exigeant un redémarrage, mais avec une perte d'altitude possible. Mission et calibration sont mises en pause, puis reprises explicitement.

Les erreurs de descripteur indiquent désormais le numéro du moteur et renvoient au formulaire au lieu du seul message `Descriptor schema/field count`. Les consignes restent séparées du montage figé en vol ; les autres architectures et le contrôleur standard sont inchangés.

## Validation et limites

Les contrats lisible/compact, les modèles par rotor, la conservation du collectif sous demande de couple impossible, les consignes sans réinitialisation et le rejet des observations périmées sont vérifiés dans le LuaJ du JAR Cosmonautics audité. Les imports passent par SNBT, sérialisation NBT binaire et CODEC natif ; chaque nœud reste sous 60 000 octets UTF modifié.

Le banc indépendant exécute 24 mouvements sur 24 géométries et motorisations. Il conserve chaque trace et les critères d'échec, notamment sous faibles inerties, retard radio, hélices hétérogènes et charge pendulaire. Voir [les résultats et sources gelées](reports/quad-campaign-0.3.5/README.md) et [le résumé de livraison](reports/quad-fpv-0.3.5/README.md). Les critères ne sont pas relâchés pour le correctif.

Ce modèle ne reproduit pas le solveur de joints Minecraft, les collisions, les réseaux de stress, l'effet de sol ou les couples gyroscopiques des hélices. Les 20 Hz de calcul simulé ne garantissent pas la latence du serveur. La navigation et la calibration ne sont pas qualifiées par les seuls essais de stabilisation. Les profils en échec restent expérimentaux ; conserver une altitude suffisante pour les essais progressifs dans Minecraft.

La campagne 0.3.4 donnait **386 PASS / 166 FAIL / 24 REFUSED**. La [campagne actuelle et ses régressions](reports/quad-campaign-0.3.5/FINDINGS.md) sont publiées séparément : le gain ciblé sur les charges ne qualifie pas tous les montages.

Résultats 0.3.5 : 406/576 réussites générales, 146 échecs et 24 refus prévol ; 29/48 réussites avec câble, dont les huit maintiens. Quatre anciennes réussites générales régressent. Les données et limites sont publiées dans le [résumé de livraison](reports/quad-fpv-0.3.5/README.md).
