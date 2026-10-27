# Validation 0.4.0

Tests du vrai LuaJ Cosmonautics 26.08.307 : six graphes dédiés, montage, clavier, armement, paramètres figés en vol, consignes acquittées, journal et protection bornée. Tests de génération déterministe, limites UTF modifié, vrais SNBT/NBT et codec natif. Les pages du journal sont vérifiées dans Lua puis Python et rejouées dans LuaJ.

Le banc physique séparé contient 96 cas (4 montages × 8 mouvements × 3 variantes), leurs critères, leurs 96 courbes et traces complètes : [rapport dans le dépôt](../operations-physics-0.4.0/README.md). Il n’est pas inclus dans l’archive de vol. Les 32 traces à enveloppe inchangée sont identiques à la 0.3.5. La limitation d’inclinaison améliore certains cas et ne résout pas les forts retards ; les échecs ne sont pas masqués.

Aucune qualification Minecraft ni garantie universelle de stabilité. L’identification passive est un candidat collectif, le rejeu impose les poses mesurées et ne prédit pas une trajectoire alternative. Voir OPERATIONS.md et IMPLEMENTATION-STATUS.md pour les fonctions ouvertes et les limites d’API.

Les compteurs et commandes reproductibles sont aussi conservés dans `validation.json` (dépôt). Le scénario de limitation imposée à 0,5 n’est pas une campagne physique en boucle fermée de la politique adaptative.
