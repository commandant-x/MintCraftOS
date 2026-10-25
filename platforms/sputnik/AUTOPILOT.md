# Sputnik 0.2.2 — autopilote commun

Choisir le **[TXT de votre architecture](README.md)**. Les graphes quad, ballon, Venator et hélicoptère préchargent leur montage, proposent des formulaires simples et omettent la carte. Les paramètres moins courants restent accessibles dans Expert et par import/export MCV1. Le graphe universel avancé reste **`dist/mintcraft-autopilot.clipboard.txt`**. Copier son contenu intégral, puis le coller dans le fond du graphe Sputnik. Le `.lua` seul ne contient pas les panneaux et raccordements. Faire la mise à jour au sol, avec une coupure mécanique indépendante engagée : supprimer l’ancien contrôleur avant d’utiliser les mêmes fréquences. Une suppression ou un redémarrage du calcul peut laisser expirer les sorties Link vers zéro, donc plein régime sur ces transmissions. La bibliothèque SDK n'est pas un nœud à importer.

Cible auditée : Cosmonautics **26.08.307**, Aeronautics/Simulated **1.3.2**, Sable **2.0.6**, Minecraft **1.21.1**. Lua seul, sans CC. Les essais automatisés ne remplacent pas une validation dans Minecraft. Le signal `Flight qualified` reste donc à zéro.

## 1. Montage

Les graphes par architecture contiennent quatre formulaires (six pour le Venator), un agrégateur limité à ces entrées, le clavier, les consignes et un seul contrôleur ; la carte reste facultative. Le texte suivant décrit le graphe universel avancé : il contient huit formulaires de groupes, un agrégateur, le clavier, les consignes, la carte et **un seul émetteur physique**. Les autres nœuds ne commandent aucun moteur. L'agrégateur accepte jusqu'à 32 groupes : ajouter des copies avec des numéros distincts et les connecter aux entrées suivantes de l'agrégateur.

1. Laisser le levier Enable sur OFF. Régler sa paire Link dédiée et les six paires du typewriter. Elles doivent être distinctes des moteurs. Cocher « Signaux maintenus » uniquement après avoir vérifié le retour à zéro au relâchement.
2. Dans un TXT par architecture, le profil et les modèles initiaux des groupes sont déjà chargés. Dans le graphe universel, choisir 1 quad, 2 ballon, 3 Venator, 4 hélicoptère ou 5 hybride. Dans chaque groupe utilisé, charger le modèle d'architecture, puis renseigner le montage réel. Un modèle est un point de départ, pas un scan des blocs.
3. Déclarer positions X/Y/Z par rapport au centre de masse et directions de poussée normalisées. Le centre de masse complet et la coque ne sont pas exposés par cette API : les positions restent déclarées. Les coordonnées de navigation sont celles de la pose racine Sable.
4. Déclarer les fréquences puissance, inverseur et clutch, ainsi que leur polarité. Tous les moteurs partageant une fréquence constituent **un groupe**, avec le nombre de moteurs dans `members`. Ils doivent avoir les mêmes caractéristiques et une position résultante cohérente. Pour des moteurs différents, déclarer des groupes indépendants réellement commandables.
5. Renseigner le **rayon englobant coque, pales et marge**, pas seulement la distance des moteurs. Il doit au moins englober toutes les positions déclarées. Confirmer le montage et la zone d'essai réellement dégagée.
6. Sauvegarder et fermer l'éditeur. Attendre l'état « Prêt », puis activer Enable sans touche pressée. Après tout redémarrage, un nouveau passage physique OFF est obligatoire. Fermer l'éditeur ne coupe pas le calcul serveur.

### Types et paramètres

| Type | Modèle utilisé | Données nécessaires |
| --- | --- | --- |
| 1 petite hélice | poussée RPM × pression × correction d'écoulement | régime source, direction, position ; coefficients par défaut 1 et 0,1 |
| 2 modulaire | poussée `0,2 × voiles^1,5 × RPM` ; airflow `0,05 × sqrt(voiles) × RPM` | **nombre de voiles propre à chaque hélice**, positions et direction ; coefficients serveur si modifiés |
| 3 réponse locale | force ou couple par niveau autour d'un neutre connu | gain N/niveau ou N·m/niveau, neutre connu, rampe, contribution au support |
| 4 gouverne | couple local proportionnel au niveau et à `Vavant × abs(Vavant)` | gain de gouverne, paire gauche et paire droite ; aucune autorité à l'arrêt |

Les champs poussée/airflow laissés vides sélectionnent les défauts du type. **Pour quatre hélices de 12 voiles : mettre 12 dans chacun des quatre groupes**, pas 48 dans un groupe. Des surfaces différentes donnent des trims et temps de réaction différents.

Les transmissions hélice utilisent **0 = régime source, 1 = 14/16 du régime, …, 14 = 1/16, 15 = arrêt**. Le levier Enable autorise le pilote ; son signal n'est jamais envoyé comme consigne commune aux hélices. Le pilote calcule chaque sortie entière 0–15, avec quantification coordonnée. Le régime source validé est au plus 256 RPM dans cette édition.

Le type « réponse locale » exige un fonctionnement connu. Il ne découvre pas un neutre de brûleur ou de mécanisme par un balayage aveugle. Le modèle de brûleur est local ; les délais thermiques réels doivent être vérifiés. Les défauts des modèles d'architecture ne constituent pas des gains mesurés de votre véhicule.

### Architectures

- **Quad** : quatre groupes de sustentation, inclinaison pour se déplacer, petites hélices ou modulaires hétérogènes. Quatre hélices verticales fixes n'apportent pas d'autorité indépendante de lacet : le virage change la trajectoire, pas un cap du nez promis.
- **Ballon** : sustentation locale connue ou hélice analogique, propulsion et inverseur facultatif, deux sorties de gouverne. Une gouverne dépend du mouvement ; les routes serrées restent expérimentales et peuvent être suspendues pour absence de convergence.
- **Venator** : quatre sustentations et deux banques arrière. Deux moteurs identiques par banque = `members=2`. Les deux banques ont chacune puissance et inverseur. Le mélange différentiel permet avance/recul et rotation lorsque la géométrie et les commandes le permettent.
- **Hélicoptère** : sustentation principale, propulsion et commandes de lacet. Aucun tangage/roulis correcteur n'est inventé si le montage n'en possède pas. Une sustentation centrée sans commandes d'assiette ne peut pas corriger une perturbation d'assiette arbitraire.
- **Hybride** : composition des groupes précédents ; capacités calculées à partir de la matrice déclarée, puis vérification par déplacement. Ce sélecteur n'ajoute aucun axe mécanique absent.

## 2. Essais automatiques

Depuis un maintien connu, choisir **mode 9 essais**, Appliquer, puis sauvegarder-fermer. La préparation vérifie télémétrie, configuration, cohérence de portance et équilibre du modèle. La séquence mesure repos, petites sollicitations individuelles, récupération, montée/descente, avance/retour et, lorsque disponible, recul et lacet.

Un palier stationnaire exige **20 observations fraîches successives**, `abs(Vy) ≤ 0,1 m/s`, vitesse horizontale ≤ 0,1 m/s, dispersion d'altitude ≤ 0,2 m et assiette/rates acceptables. Un délai écoulé n'accorde aucune réussite. Les quatre observations d'une sollicitation individuelle caractérisent un échantillon de réponse transitoire ; elles ne certifient pas un palier stationnaire. Le diagnostic indique la phase, les vitesses et le compteur de stabilité.

Modes 10/11 : pause/reprise ; 13 : abandon en conservant les mesures. Une touche pilote suspend les essais et demande une reprise explicite. Le maintien vertical reste actif. Les essais restent dans une zone déclarée dégagée, sans détection d'obstacle.

Les réponses enregistrées `MCAL1` sont des **candidats de mouvement**, avec empreinte du groupe et masse de référence. Une pause ou une fin de calibration conserve un instantané ; une nouvelle séquence peut reprendre ces candidats, mais recommence leur vérification. Pendant le calcul serveur, un ancien cache client ne remplace pas cet instantané. Après rechargement, chaque groupe est revérifié. Elles ne constituent ni une courbe complète de poussée identifiée, ni un acquittement Link, ni une identité matérielle. La matrice de contrôle repose encore sur le modèle renseigné. La réutilisation sans refaire tous les essais, l'identification complète des retards/couplages et la reprise matérielle non instrumentée restent à compléter.

## 3. Pilotage

Les champs altitude, vitesse et cap sont séparés des fréquences. Les boutons nommés en haut du panneau appliquent directement les actions courantes ; le sélecteur numérique et son bouton Appliquer restent réservés aux actions avancées. **Appliquer**, puis sauvegarder-fermer envoie une demande persistante `MCC1`, identifiée par révision. Le panneau indique la révision réellement acceptée et le motif d'un refus. Modifier une consigne conserve les filtres et le maintien vertical. Une modification de montage en vol reste en attente du désarmement.

| Mode | Action |
| --- | --- |
| 1 | maintien à la hauteur courante |
| 2 | atteindre l'altitude saisie et la conserver |
| 3 | vitesse et cap de trajectoire ; cap du nez seulement si commandable |
| 4 | suivre la route après essais de déplacement réussis |
| 5 / 6 | pause / reprise explicite de mission |
| 7 | annuler la mission, conserver le maintien vertical |
| 8 | retour à la position de départ après préparation |
| 12 | reprise directe, suspension de mission/essais |

Le clavier conserve W/S, Q/D, Espace/Shift. Au relâchement, le pilote freine ; Espace/Shift déplacent la consigne d'altitude. Q/D utilisent les capacités présentes : lacet lorsque commandable, sinon virage de trajectoire du quad. Dans Montage, décocher le virage Q/D active le déplacement latéral du quad. Les touches supplémentaires de lacet ne sont pas encore fournies par le panneau.

**Pause, arrêt horizontal, désarmement et coupure mécanique sont différents.** Les entrées natives `Stop horizontal` et `Mechanical cut` sont disponibles sur le contrôleur pour raccorder des commutateurs physiques dédiés. Elles ne sont pas des boutons client instantanés. La coupure mécanique n'est pas un maintien en vol ; elle reste verrouillée jusqu'à un nouveau OFF/ON. OFF utilise le repli configuré ; `fallback=-1` capture le trim estimé au départ, pas une garantie de maintien après changement de masse.

Une inversion réduit la puissance et mémorise la demande jusqu’au passage par l’arrêt ; une nouvelle correction de couple ne peut pas annuler cette étape à chaque tick. Elle attend l’arrêt estimé de l’arbre. Des entrées facultatives `Shaft RPM`, `Shaft sample tick`, `Shaft sample valid` peuvent remplacer cette estimation par une mesure fraîche. Un arrêt mesuré exige un échantillon frais postérieur à la demande d’arrêt. La trame de changement de sens reste à puissance arrêtée. Sans retour d’arbre valide, le diagnostic dit **arrêt estimé, non confirmé**. Le mouvement du véhicule ne prouve pas l'état de l'inverseur.

Le rapport conserve le premier défaut et un historique borné, les sorties demandées, l'état estimé et les capacités. Un ACK de révision confirme une consigne logicielle acceptée, pas sa réalisation mécanique.

## 4. Navigation et persistance

Route : `x,y,z,vitesse;x,y,z,vitesse`. Au plus 64 points, vitesse 0 = automatique selon approche/freinage ; aucune limite absolue de déplacement ajoutée. Zones interdites : `xmin,ymin,zmin,xmax,ymax,zmax;...`, au plus 16 boîtes, dilatées par le rayon déclaré.

Le planificateur 3D contourne ces boîtes déclarées, répartit son travail entre ticks et recalcule si la liaison depuis la position observée traverse une boîte. Le freinage observé réduit prudemment la décélération de planification ; un modèle de freinage configuré reste nécessaire au départ. Les propulsions pouvant tourner à l’arrêt commencent par s’aligner lorsque l’écart de cap dépasse 20° ; cette phase observe la convergence du cap plutôt que celle de la position. Une gouverne dépendante du mouvement ne peut pas utiliser cet alignement à l’arrêt. Une absence de convergence suspend la mission et conserve la hauteur. L'arrivée se termine par un maintien, **pas un atterrissage**.

La carte montre les groupes et les points de coque déclarés (champ facultatif, 256 points maximum), la route, la position et la trace, avec vues dessus/côté/face/3D. **Aucun terrain n'est scanné ; la coque affichée est uniquement celle déclarée.** Les espaces inconnus ne sont pas déclarés libres. La fermeture de l'éditeur conserve les champs dans le graphe natif. Dans les graphes simples, les descripteurs MCV1 s’exportent/importent par groupe et l’agrégateur lit toujours ces formulaires. Le graphe universel avancé conserve l’import global explicite. Le contrôleur valide les descripteurs et les doublons. Les routes nommées (16 maximum) se sauvegardent dans la bibliothèque textuelle MCR1 du panneau. Le bouton position courante ajoute un point ; le sélecteur permet de charger, remplacer ou retirer un point. Les modèles sauvegardés restent candidats. Le cache client ne peut pas restaurer l'armement ou relancer une ancienne mission.

## 5. Adaptation, limites et validation

La masse et les inerties diagonales disponibles sont relues côté serveur. L'allocation et la correction verticale s'adaptent en conservant la consigne de hauteur, sans balayage en mission. Après une variation de masse observée, un trim d’assiette borné peut se corriger en maintien ou au repos de calibration ; il est figé pendant les déplacements et les sollicitations. Il ne constitue pas une identification de pale manquante. La récupération d'assiette suspend les demandes horizontales dans le domaine contrôlable ; elle ne garantit pas de redresser un véhicule retourné ou un axe absent. Une réponse dégradée ne prouve pas qu'une pale a disparu.

Limites Lua : absence de scan des voiles/COM/coque, preuve d'appartenance, terrain/obstacles garantis, contact d'atterrissage, acquittement mécanique natif et reprise physique après arrêt complet du calcul. Les émetteurs Link expirent : zéro peut signifier plein régime. Le contrôleur rafraîchit le repli tant qu'il s'exécute ; un clutch/interverrouillage physique indépendant reste nécessaire pour une coupure garantie après disparition du calcul.

Voir [l'état des lots](IMPLEMENTATION-STATUS.md) et les rapports `reports/universal-0.2.0`. Les scénarios réussis définissent un domaine de simulation, pas une qualification universelle ou Minecraft. Les scripts natifs sont contrôlés sous 60 000 octets UTF modifié et les imports sont vérifiés par le vrai parseur SNBT et le codec Sputnik.
