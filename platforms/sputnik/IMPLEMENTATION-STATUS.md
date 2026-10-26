> 0.3.4 : rééquilibrage passif du quad après déplacement de charge, sans modifier la consigne verticale ; voir [QUAD-FPV.md](QUAD-FPV.md). Contrôleurs standard inchangés. Domaine synthétique et échecs publiés, distincts du vol Minecraft.

# État d'implémentation — Autopilote Sputnik 0.3.4

Le plan A–F reste la cible. Cette livraison ajoute le graphe commun et les contrôleurs effectifs ; **elle ne déclare pas tous les critères du plan terminés**. Les limites ci-dessous sont suivies explicitement plutôt que masquées par le sélecteur d'architecture.

| Lot | Livré | Reste à valider ou compléter |
| --- | --- | --- |
| A Montage | Descripteur versionné commun, formulaires préchargés par architecture (4/6 groupes) et graphe avancé à huit formulaires extensibles à 32 groupes, fréquences/auxiliaires, voiles par rotor, groupes partagés, télémétrie native, conflits et montage figé en vol | Assistant en une seule fenêtre ; description de moteurs hétérogènes partageant une sortie ; géométrie COM réelle indisponible en Lua |
| B Contrôle | Allocation physique commune, quad hétérogène, sustentation locale, banques différentielles, gouverne dépendante du mouvement, lacet disponible, séquence inverseur mémorisée avec arrêt frais ou estimé, capacités séparées | Domaine gouverne/virages serrés ; réponses thermiques spécifiques ; toutes les variantes mécaniques réelles |
| C Calibration | Repos mesuré 20 observations, sollicitations bornées depuis état connu, récupération, montée/descente, déplacement/retour et tests conditionnels, pause/abandon, sauvegarde des résultats partiels, candidats persistants protégés du cache client | Identification complète des courbes/retards et des couplages ; validation sélective sans séquence complète ; essais de reprise physique instrumentés |
| D Interface | Montage/Pilotage/Navigation séparés, boutons nommés, formulaires moteur simples avec expert conservé, consignes persistantes et ACK logiciel, bibliothèque de routes, édition par point et position courante, clavier six touches, diagnostic, premier défaut, arrêt horizontal distinct de coupure | Navigation entièrement sans saisie, boutons/commutateurs dédiés prêts à l'emploi pour arrêt/coupure, commandes de lacet optionnelles |
| E Adaptation | Quaternions, allocation/quantification couplées, correction de masse et trim d’assiette en maintien sans changer la cible, récupération d'assiette, suspension horizontale si réserve verticale insuffisante | Validation systématique très faibles inerties et délais élevés ; adaptation de réponse/panne sans modèle renseigné |
| F Missions | Planificateur 3D local borné, zones/marges déclarées, routes XYZ, pause/reprise/retour, freinage passif, trace, points de coque déclarée, vues natives 2D/3D, maintien final | Contraintes de virage et de freinage garanties sur toute la trajectoire ; cartes terrain impossibles sans source réelle |

Le banc indépendant distingue les succès, les échecs et les hypothèses. Les mesures de déplacement ne deviennent pas des ACK matériels. Le drapeau global de qualification reste faux. La livraison n'a pas été essayée dans le monde Minecraft du joueur.

## Ajout 0.3.0 : quad rapide séparé

Quantification collective synchronisée, réponse verticale directe, référence d’inclinaison amortie, réserve de portance prédictive, compensation passive de charge non exposée par la masse et récupération sans verrouillage sur angle. Référence modulaire identique : 12/12 scénarios synthétiques LuaJ passent. Stress faible inertie/retard : 2/4 ; corde longue avec balancement : 2/3. Ces échecs restent ouverts. Le profil rapide refuse les petites hélices et les hélices hétérogènes ; le contrôleur standard reste inchangé. Les missions et la calibration du profil rapide ne sont pas qualifiées par ces essais de stabilisation.

## Correction 0.3.1 : maintien résonant

Retrait de l’adaptation multiplicative sensible à la chute, biais vertical additif borné, assiette de maintien moins agressive et freinage compensé après relâchement. Banc élargi aux démarrages à froid, perturbations diagonales, chute, retard accru et erreur de réponse rotor ; mesure crête-à-crête verticale ajoutée. Les résultats 0.3.0 ne suffisaient pas à valider ces situations. Voir les nouveaux rapports avant de conclure sur le domaine pris en charge.

## Correction 0.3.2 : allocation et dynamique du quad

Priorité collective en maintien, réponse par rotor, hélices petites/modulaires hétérogènes acceptées expérimentalement, observateur passif de couple et virage fondé sur la trajectoire mesurée. La récupération conserve une priorité d'assiette et peut perdre de la hauteur. Les défauts de descripteur identifient le moteur. Le sélecteur universel et les autres contrôleurs ne changent pas.

La campagne lourde 0.3.1 avait révélé que la validation précédente était insuffisante : aucun montage accepté ne réussissait tous les 24 mouvements. La version corrigée est réévaluée avec les mêmes critères, sans transformer un refus en réussite. Voir [campagne 0.3.2](reports/quad-campaign-0.3.2/README.md). Le plan A–F reste incomplet ; les cas en échec ne sont pas déclarés opérationnels.

## Correction 0.3.3 : modulation continue à régime fixe

Suppression du raccourci qui remplaçait les demandes presque égales par une sortie commune et effaçait les petites corrections différentielles. Un seul quantificateur couplé conserve désormais le résidu de couple, y compris près du maintien. Régime source 256 RPM, transmissions 0–15, géométrie, gains et interface conservés ; aucune modification mécanique demandée. La régression couvre les faibles couples signés et les départs inclinés. Voir [les mesures comparées](reports/quad-pwm-0.3.3/README.md). La campagne publie toujours les cas en échec ; le plan A–F n'est pas entièrement qualifié.

## Correction 0.3.4 : charge décentrée

Le quad adapte les bras de levier effectifs à partir des commandes émises et des accélérations angulaires, conserve la cible verticale et utilise la famille complète des allocations bornées. Aucun nouveau champ de centre de masse ni impulsion de calibration. Le contrôleur standard reste identique. Les [72 scénarios de charge](reports/quad-com-0.3.4/README.md) publient 15/36 succès COM contre 6/36 auparavant et tous les échecs : cette adaptation ne qualifie pas tous les centres de masse, retards ou manœuvres. Les critères COM et les anciens critères de campagne sont séparés. Le plan A–F reste incomplet.
