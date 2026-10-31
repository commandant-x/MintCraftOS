# Recherche — prise en main et calculs Sputnik

État examiné : 0.4.0, commit `f60609faa14c490b04e493753e2f3f9fa59aac4b`. Sources consultées le 31 octobre 2026. Ce document propose la suite ; il ne modifie pas le contrôleur distribué et ne constitue pas une qualification de vol.

Le problème comporte deux parties : rendre la configuration lisible et tenir compte du temps réellement nécessaire aux actionneurs. Augmenter tous les gains ou masquer davantage de paramètres ne suffit pas. Les recommandations ci-dessous croisent le code, les échecs des campagnes et des références de commande de vol.

## 1. Ce que montre la version actuelle

| Constat vérifié dans le code | Conséquence | Suite recommandée |
| --- | --- | --- |
| `mount-workbench.lua` sélectionne un groupe avec un curseur 1–32, sans vue simultanée des quatre coins | L’utilisateur croit avoir une seule hélice et peine à repérer un groupe oublié | Quatre sélections nommées et un récapitulatif toujours visible |
| `command-node.lua` ajoute tous les boutons, routes et champs techniques au même panneau | Le pilotage courant se perd dans les outils de configuration | Séparer l’usage quotidien des outils avancés, sans perdre leur persistance |
| Les consignes passent par une demande et un acquittement serveur ; le client peut afficher un cache | Une valeur saisie n’est pas nécessairement appliquée | Afficher côte à côte « demandée », « acceptée » et l’état de transmission |
| La récupération utilise déjà les quaternions et le vecteur de poussée | Remplacer simplement Euler par quaternion ne résoudrait pas les oscillations | Tester les transitions et les limites de l’allocation existante |
| La dynamique des hélices est estimée à partir des commandes, sans mesure d’arbre garantie | Une anticipation mal synchronisée peut corriger un état qui n’existe pas encore | Dater les commandes et aligner leur historique avec les observations |
| L’intégration verticale dépend du résultat d’allocation continu, avant quantification et montée en régime | La poussée calculée peut différer de celle estimée après émission | Utiliser un retour d’allocation compatible avec la dynamique et les niveaux discrets |
| Le gain vertical passe de 2 à 4 lorsqu’un effort extérieur estimé dépasse 10 % de la gravité, ou pendant une touche verticale | Une variation autour du seuil peut modifier brutalement la réponse | Tester une transition continue ou une hystérésis, avec suivi des changements |
| Le trim de couple et l’effort vertical sont adaptés simultanément | Un balancement peut être interprété comme un déséquilibre permanent | Séparer adaptation lente et mouvement périodique ; surveiller l’excitation et la confiance |

Les causes exactes des oscillations du véhicule réel ne sont pas établies par ces seuls constats. Chaque point est une hypothèse à isoler sur le banc, puis sur des observations en jeu.

Les 96 cas de la livraison 0.4.0 comparent trois variantes de 32 mouvements : référence, nouvelle version à enveloppe identique, enveloppe imposée à 50 %. Les deux premières réussissent 23/32 cas, la dernière 24/32. Les 32 traces à enveloppe identique sont identiques octet par octet. Ce résultat valide une non-régression sur ces cas ; il ne prouve ni disparition des oscillations ni efficacité physique de la politique adaptative complète.

## 2. Prise en main proposée

La divulgation progressive [S1] consiste à garder les fonctions courantes visibles et à rendre les fonctions secondaires accessibles au besoin. Dans Sputnik, cela doit réduire ce qui est présenté, pas simplement déplacer tous les champs dans un autre long bloc.

### Montage

- Quatre sélections explicites : **Avant gauche**, **Avant droite**, **Arrière gauche**, **Arrière droite**. Les architectures à d’autres groupes affichent leurs noms mécaniques. Un identifiant interne reste disponible en avancé.
- Un tableau permanent : groupe, actif/inactif, type, voiles, régime, fréquence configurée, validation. Le nombre de commandes indépendantes doit être distinct du nombre de moteurs mécaniques.
- Vue de dessus déclarée avec avant du véhicule et groupe sélectionné surligné. Les coordonnées, le repère et le rôle doivent rester visibles ; ils ne proviennent pas d’un scan.
- Trois niveaux d’information : données nécessaires au modèle, contrôles facultatifs présents sur le montage, puis expert/import/export. Ne pas demander un inverseur ou clutch absent.
- Action « recopier les caractéristiques » limitée aux propriétés compatibles : type, voiles et régime. Ne jamais dupliquer automatiquement les fréquences ni les positions ; conserver un contrôle des conflits.
- Pour un quad symétrique, saisir les dimensions une fois puis proposer les positions des quatre coins. Toute exception reste éditable et visible. Le centre déclaré n’est pas annoncé comme centre de masse mesuré.
- Contrôle guidé des sens et du groupe visé à partir d’un modèle connu. Une commande émise reste distincte d’une réponse observée. Aucun balayage aveugle de 0 à 15 pour découvrir le neutre.

Le curseur numérique actuel serait conservé uniquement pour les montages personnalisés. Les boutons de sélection peuvent utiliser les éléments natifs déjà disponibles ; il faut tester la sauvegarde des champs qui ne sont plus montrés. Masquer des widgets sans conserver leurs valeurs dans les champs sérialisés indépendants pourrait réintroduire les pertes de configuration.

### Pilotage quotidien

La vue principale devrait montrer altitude actuelle/cible acceptée, vitesse verticale, vitesse horizontale, mode, disponibilité du contrôle de cap et état de stabilité. Trois actions principales : **Maintenir ici**, **Appliquer l’altitude**, **Reprendre le clavier**. Les missions restent dans Navigation ; les essais dans Montage.

Les demandes doivent afficher « en attente serveur », « acceptée, révision N » ou une raison précise de refus. La procédure sauvegarder/fermer reste explicitée tant que l’API impose cette synchronisation ; un bouton client ne prouve pas une application immédiate au serveur.

Les réglages de comportement sont séparés : vitesse de montée, accélération horizontale, freinage et vitesse de croisière. Le mode de Q/D indique explicitement **déplacement latéral** ou **virage de trajectoire**. Quatre hélices fixes sans couple de lacet déclaré ne permettent pas de promettre une rotation du nez.

Arrêt horizontal, pause de mission, reprise clavier et coupure mécanique restent distincts. La couleur ou le texte « moteur configuré » ne signifie jamais « moteur physiquement confirmé ».

### Diagnostic utile

Afficher la raison exploitable avant les nombres internes : « arrière droit non configuré », « réserve de poussée insuffisante », « observations périmées », « oscillation observée », « configuration en attente OFF ». Conserver le premier défaut et un accès au rapport complet, sans imposer la lecture des paquets MCV/MCU/MCLOG pour piloter.

## 3. Calculs : priorités techniques

### 3.1 Mesurer la chronologie avant d’augmenter la réactivité

PX4 décrit explicitement le compromis entre filtrage, bruit et latence [S2]. Notre code traite les ticks en unités de 1/20 s. Cela ne prouve pas une cadence de 20 Hz sans lacune dans Minecraft : il faut mesurer les observations fraîches, les intervalles et les retards du graphe.

Le filtre discret actuel de constante `.12 s`, avec `dt=.05 s`, a un coefficient `a=dt/(.12+dt)`. Pris isolément, son retard de phase à 1 Hz vaut environ **33,6°**. Un retard pur de **100 ms** ajoute **36°** à 1 Hz. Les différents filtres ne sont pas tous en série ; on ne peut pas additionner arbitrairement leurs retards pour conclure sur la stabilité de la boucle entière.

À ajouter aux preuves : tick de pose, tick de calcul, commande émise, historique des sorties et âge du modèle utilisé. Sans retour matériel, le retard commande→arbre reste estimé, jamais acquitté. Comparer les traces pour plusieurs hypothèses de délai et pour des ticks manquants.

Ne pas recopier les coupures 80–120 Hz d’un pilote réel mentionnées dans PX4 : une observation à 20 Hz a une fréquence de Nyquist de 10 Hz. Répéter dix calculs sur la même observation ne crée pas dix mesures nouvelles.

### 3.2 Conserver la physique du mod

Le modèle audité dans `aero_physics.lua` n’est pas la loi classique de drone réel « poussée proportionnelle au carré du régime ». Il utilise le régime, la pression et l’écoulement axial selon la formule du mod, avec saturation de l’écoulement. Les références de drones donnent une structure de commande ; leurs coefficients ne se copient pas dans Simulated.

La transmission comporte également une discontinuité : à 256 RPM source, le niveau 0 donne 256 RPM, le niveau 1 donne 224 RPM et le niveau 15 donne l’arrêt. Il n’existe pas de commande physique 240 RPM. Une moyenne temporelle entre deux niveaux n’est pas un niveau redstone fractionnaire.

Pour les hélices modulaires, le code utilise `alpha=.4/sqrt(voiles)`. Pour une réponse idéale au premier ordre à 20 Hz :

| Voiles | Constante de temps du modèle | Temps idéal pour 90 % du changement de régime |
| ---: | ---: | ---: |
| 4 | 0,224 s | 0,516 s |
| 12 | 0,408 s | 0,938 s |
| 24 | 0,587 s | 1,352 s |
| 48 | 0,841 s | 1,936 s |

Calcul : `tau=-.05/log(1-alpha)` ; `t90=tau*log(10)`. Ce sont des résultats du modèle existant, pas des mesures du serveur. Les références d’assiette et la transmission ajoutent d’autres dynamiques. Une réaction de l’ordre d’une seconde peut donc avoir une origine mécanique/modélisée, pas seulement un manque de puissance du calcul.

### 3.3 Allocation et quantification prédictives par rotor

Le quad possède déjà une allocation couplée et un quantificateur explorant les combinaisons plancher/plafond. Il faut les améliorer, pas annoncer cette fonction comme entièrement absente.

L’étape suivante serait d’évaluer chaque combinaison en propageant l’état estimé de chaque rotor avec son propre retard et sa montée en régime. Pour quatre rotors, les deux niveaux adjacents donnent au plus **16 combinaisons** par évaluation. Un petit horizon borné permettrait de comparer erreur collective, couples, saturation et variation des commandes. Le coût réel doit être mesuré dans LuaJ.

La priorité est contextuelle : maintien de portance en vol normal, redressement lorsque l’assiette exige de sacrifier de la hauteur. La pénalité de changement de niveau ne doit pas empêcher une correction urgente. La diffusion d’erreur doit être comparée à cette approche : la supprimer sans test pourrait perdre les petits couples nécessaires à l’équilibre.

Ce modèle prédictif ne devient utile que si les délais sont cohérents. Tester des erreurs de modèle et ne pas surcompenser une prédiction incertaine. Les commandes de groupes mécaniquement liés ne deviennent pas des degrés de liberté indépendants.

### 3.4 Boucles séparées et anti-emballement

PX4 sépare position, vitesse, attitude, vitesse angulaire et allocation [S3, S4]. Le code Sputnik possède déjà plusieurs de ces composants ; la suite est de rendre explicites leurs références, limites et retours de saturation, pas de supposer qu’il faut tout remplacer par un PID.

- Boucle d’assiette/rates sur chaque observation fraîche, puis vitesse/altitude avec une dynamique plus lente compatible avec les actionneurs.
- Anti-windup fondé sur ce que l’allocation peut fournir dans le sens demandé. Le code PX4 limite l’intégration suivant le signe de saturation [S5]. Chez nous, tenir aussi compte du niveau discret et de la poussée **estimée**, correctement alignée dans le temps.
- Adaptation du trim et de l’effort extérieur plus lente que les transitoires qu’elle ne doit pas absorber. Comparer une adaptation ralentie, gelée pendant excitation et réactivée sur confiance mesurée.
- Transition sans saut entre maintien, touche verticale, freinage, charge estimée et récupération. Tester spécifiquement le seuil qui double actuellement le gain vertical.
- Références d’accélération avec variation bornée — jerk — plutôt qu’à-coups suivis d’un freinage opposé. PX4 utilise des trajectoires de ce type [S6]. Réglage selon les capacités et le choix opérateur, sans nouveau plafond arbitraire de vitesse.

### 3.5 Changement de centre de masse et charge suspendue

La masse exposée ne suffit pas à déterminer le centre de masse, l’inertie totale d’un ensemble articulé ou l’angle d’une charge suspendue. L’observateur de couple actuel corrige déjà un déséquilibre effectif ; il ne prouve pas un déplacement physique du COM.

L’amélioration réaliste sans entrée supplémentaire est un observateur borné d’efforts et couples, distinguant biais lent et oscillation. Adapter le maintien avec la même altitude cible ; réduire l’excitation lorsque l’incertitude monte. Une estimation du rythme de balancement demande plusieurs périodes et une fenêtre adaptée : six secondes de données ne suffisent pas forcément à caractériser une longue corde.

La solution de charge suspendue documentée par ArduPilot demande explicitement une télémétrie de position sur la charge à 10 Hz [S7]. Nous ne disposons pas de cette information. On peut chercher une atténuation robuste à partir du mouvement du porteur, mais pas promettre la même compensation ni une stabilité parfaite pour toute corde et tout poids non observés.

### 3.6 Retournement

Les méthodes géométriques évitent les singularités d’Euler et permettent d’étudier la récupération depuis une attitude inversée [S8]. La publication citée présente un modèle et des exemples numériques, pas une garantie pour Sputnik à 20 Hz avec transmissions lentes et sans autorité de lacet.

Conserver le contrôle de direction de poussée déjà présent, un choix déterministe à 180°, des transitions avec hystérésis et des objectifs réalisables par l’allocation. Publier le temps de redressement, la hauteur perdue et les cas où l’autorité disponible est insuffisante. « Tenter de se redresser » et « garantir le maintien d’altitude à l’envers » sont deux exigences différentes.

## 4. Coût de calcul et contraintes de livraison

- Contrôle physique sur observations nouvelles ; aucune réinitialisation lors d’un simple changement de consigne.
- Rendu et formatage de textes à cadence réduite, seulement lorsque les valeurs utiles changent. Le diagnostic à 4 Hz est déjà séparé ; ne pas le recompter comme une nouveauté.
- Pré-calculer la géométrie déclarée, mais recalculer ce qui dépend réellement de masse, inerties, pression, direction, trim et vitesse d’air. Une matrice entière ne peut pas être cachée sans invalidation.
- Réutiliser des tableaux et borner les fenêtres d’observation, l’horizon prédictif et les recherches. Mesurer temps par tick et allocations mémoire dans LuaJ, puis vérifier la cadence réelle en jeu.
- Garder un propriétaire unique des sorties. Découper le calcul ne doit pas introduire un tick supplémentaire entre mesure et commande.
- Les écrivains actuels occupent environ 59 986 et 59 836 octets, pour une limite de 60 000 octets UTF modifié. Prévoir extraction/remplacement de code et budget explicite avant toute addition. Ajouter des fonctions sans ce travail casserait l’import NBT.

## 5. Ordre d’implémentation recommandé

| Priorité | Livraison | Preuve attendue |
| --- | --- | --- |
| 1 | Quatre moteurs visibles, noms des coins, tableau de configuration, états demandé/accepté | Parcours neuf complet sans paquets techniques ; sauvegarde/rechargement natifs sans perte |
| 2 | Chronologie, comparaison des prédictions rotor et retour de saturation | Traces synchronisées, traitement explicite des lacunes et incertitudes |
| 3 | Comparaison du quantificateur actuel avec prédiction bornée par rotor | Même banc, variations de voiles/délai/bruit, coût LuaJ et absence de régression |
| 4 | Gains continus, anti-windup et transitions de consigne | Pas d’à-coup au seuil d’effort ni après saturation ; altitude cible conservée |
| 5 | Adaptation lente COM/charge et références à jerk borné | Maintien, déplacement et freinage avec COM décalé, charge variable et corde, sans nouvelle saisie de charge |
| 6 | Récupération et généralisation aux autres architectures | Domaine documenté, commandes disponibles distinguées des axes impossibles |

La validation doit tester **ensemble** contrôleur, transport, quantification, supervision et retour d’allocation. La campagne 0.4.0 avec facteur 0,5 imposé ne teste pas cette boucle complète. Conserver les cas en échec, publier les excursions transitoires, vitesses, couples/saturations et temps de retour au calme. Exiger 20 observations fraîches stationnaires puis une fenêtre plus longue sans réapparition ; une seule traversée de la cible n’est pas un maintien validé.

Il faut comparer à réglages et scénarios identiques, avec simulations défavorables au modèle : retard variable, faux coefficient de poussée, voiles différents, ticks manquants, variations de masse et inertie, changement de consigne en saturation, charge périodique. Les essais Minecraft restent distincts des simulations.

## Sources consultées

- **S1 — Nielsen Norman Group, Progressive Disclosure** : fonctions principales visibles, détails secondaires accessibles au besoin. https://www.nngroup.com/articles/progressive-disclosure/
- **S2 — PX4, MC Filter Tuning & Control Latency** : filtrage, bruit, déphasage et latence. https://docs.px4.io/main/en/config_mc/filter_tuning.html
- **S3 — PX4, Controller Diagrams** : boucles position/vitesse/attitude/rates, références et saturation. https://docs.px4.io/main/en/flight_stack/controller_diagrams.html
- **S4 — PX4, Control Allocation** : séparation de la commande et de la géométrie des actionneurs. https://docs.px4.io/main/en/concept/control_allocation.html
- **S5 — PX4, implémentation RateControl** : intégration conditionnée au signe de saturation et limitation de l’intégrale. Source évolutive consultée à la date de ce document. https://github.com/PX4/PX4-Autopilot/blob/main/src/lib/rate_control/rate_control.cpp
- **S6 — PX4, Jerk-limited Type Trajectory** : profils d’accélération et de jerk bornés. https://docs.px4.io/main/en/config_mc/mc_jerk_limited_type_trajectory.html
- **S7 — ArduPilot, Slung Payload** : la solution décrite utilise une mesure embarquée sur la charge. https://ardupilot.org/copter/docs/slung-payload.html
- **S8 — Lee, Leok et McClamroch, Control of Complex Maneuvers for a Quadrotor UAV using Geometric Methods on SE(3)** : commande géométrique et exemples numériques de récupération. https://arxiv.org/abs/1003.2005

Audit local : `src/mount-workbench.lua`, `src/command-node.lua`, `src/quad-flight-step.lua`, `src/quad-pwm.lua`, `src/quad-allocator.lua`, `src/vehicle_model.lua`, `src/aero_physics.lua`, `reports/operations-0.4.0/validation.json` et `reports/operations-physics-0.4.0/`. Les liens externes proposent des principes ; les formules de force et de transmission restent celles du mod audité.
