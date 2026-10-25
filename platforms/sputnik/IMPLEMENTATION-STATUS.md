# État d'implémentation — Autopilote Sputnik 0.2.0

Le plan A–F reste la cible. Cette livraison ajoute le graphe commun et les contrôleurs effectifs ; **elle ne déclare pas tous les critères du plan terminés**. Les limites ci-dessous sont suivies explicitement plutôt que masquées par le sélecteur d'architecture.

| Lot | Livré | Reste à valider ou compléter |
| --- | --- | --- |
| A Montage | Descripteur versionné commun, huit formulaires extensibles à 32 groupes, fréquences/auxiliaires, voiles par rotor, groupes partagés, télémétrie native, conflits et montage figé en vol | Assistant en une seule fenêtre ; description de moteurs hétérogènes partageant une sortie ; géométrie COM réelle indisponible en Lua |
| B Contrôle | Allocation physique commune, quad hétérogène, sustentation locale, banques différentielles, gouverne dépendante du mouvement, lacet disponible, séquence inverseur mémorisée avec arrêt frais ou estimé, capacités séparées | Domaine gouverne/virages serrés ; réponses thermiques spécifiques ; toutes les variantes mécaniques réelles |
| C Calibration | Repos mesuré 20 observations, sollicitations bornées depuis état connu, récupération, montée/descente, déplacement/retour et tests conditionnels, pause/abandon, sauvegarde des résultats partiels, candidats persistants protégés du cache client | Identification complète des courbes/retards et des couplages ; validation sélective sans séquence complète ; essais de reprise physique instrumentés |
| D Interface | Montage/Pilotage/Navigation séparés, consignes persistantes et ACK logiciel, bibliothèque de routes, édition par point et position courante, clavier six touches, diagnostic, premier défaut, arrêt horizontal distinct de coupure | Navigation entièrement sans saisie, boutons/commutateurs dédiés prêts à l'emploi pour arrêt/coupure, commandes de lacet optionnelles |
| E Adaptation | Quaternions, allocation/quantification couplées, correction de masse et trim d’assiette en maintien sans changer la cible, récupération d'assiette, suspension horizontale si réserve verticale insuffisante | Validation systématique très faibles inerties et délais élevés ; adaptation de réponse/panne sans modèle renseigné |
| F Missions | Planificateur 3D local borné, zones/marges déclarées, routes XYZ, pause/reprise/retour, freinage passif, trace, points de coque déclarée, vues natives 2D/3D, maintien final | Contraintes de virage et de freinage garanties sur toute la trajectoire ; cartes terrain impossibles sans source réelle |

Le banc indépendant distingue les succès, les échecs et les hypothèses. Les mesures de déplacement ne deviennent pas des ACK matériels. Le drapeau global de qualification reste faux. La livraison n'a pas été essayée dans le monde Minecraft du joueur.
