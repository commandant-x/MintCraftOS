# État d'implémentation — Autopilote Sputnik 0.4.0

Le plan A–F reste la cible. Cette livraison ajoute le graphe commun et les contrôleurs effectifs ; **elle ne déclare pas tous les critères du plan terminés**. Les limites ci-dessous sont suivies explicitement plutôt que masquées par le sélecteur d'architecture.

| Lot | Livré | Reste à valider ou compléter |
| --- | --- | --- |
| A Montage | Descripteur versionné commun, formulaire unique sélectionnant jusqu’à 32 groupes avec brouillons, bibliothèque et import/export, fréquences/auxiliaires, voiles par rotor, groupes partagés, télémétrie native, conflits et montage figé en vol | Description de moteurs hétérogènes partageant une sortie ; géométrie COM réelle indisponible en Lua |
| B Contrôle | Allocation physique commune, quad hétérogène, sustentation locale, banques différentielles, gouverne dépendante du mouvement, lacet disponible, séquence inverseur mémorisée avec arrêt frais ou estimé, capacités séparées | Domaine gouverne/virages serrés ; réponses thermiques spécifiques ; toutes les variantes mécaniques réelles |
| C Calibration | Repos mesuré 20 observations, sollicitations bornées depuis état connu, récupération, montée/descente, déplacement/retour et tests conditionnels, pause/abandon, sauvegarde des résultats partiels, candidats persistants protégés du cache client | Identification complète des courbes/retards et des couplages ; validation sélective sans séquence complète ; essais de reprise physique instrumentés |
| D Interface | Montage/Pilotage/Navigation séparés, boutons nommés, formulaires moteur simples avec expert conservé, consignes persistantes et ACK logiciel, bibliothèque de routes, édition par point et position courante, clavier six touches, diagnostic, premier défaut, arrêt horizontal distinct de coupure | Navigation entièrement sans saisie et commandes de lacet optionnelles |
| E Adaptation | Quaternions, allocation/quantification couplées, correction de masse et trim d’assiette en maintien sans changer la cible, récupération d'assiette, suspension horizontale si réserve verticale insuffisante | Validation systématique très faibles inerties et délais élevés ; adaptation de réponse/panne sans modèle renseigné |
| F Missions | Planificateur 3D local borné, zones/marges déclarées, routes XYZ, pause/reprise/retour, freinage passif, trace, points de coque déclarée, vues natives 2D/3D, maintien final | Contraintes de virage et de freinage garanties sur toute la trajectoire ; cartes terrain impossibles sans source réelle |

Le banc indépendant distingue les succès, les échecs et les hypothèses. Les mesures de déplacement ne deviennent pas des ACK matériels. Le drapeau global de qualification reste faux. La livraison n'a pas été essayée dans le monde Minecraft du joueur.

## Livraison 0.4.0 : exploitation et preuves

- Montage : formulaire unique, variantes dédiées à sept nœuds, brouillons inactifs conservés et bibliothèque complète avec paramètres mécaniques. Importer un montage ne confirme pas ses essais physiques.
- Pilotage : consignes acquittées, commandes explicites retour/annulation/reprise manuelle, arrêt horizontal et coupure séparés. Modification d’une consigne sans recréer l’estimateur.
- Diagnostic : journal borné MCF1/MCLOG1, premier défaut figé, export paginé, détection de lacunes et stationnarité sur observations fraîches. Rejeu LuaJ sur poses enregistrées ; pas de trajectoire contrefactuelle garantie.
- Protection : réduction bornée de l’enveloppe d’inclinaison, comparaison de son effet puis retour au réglage précédent si aggravation observée. Pause horizontale en forte oscillation, sans coupure mécanique automatique.
- Identification : candidat collectif passif, délai/corrélation et freinage observé. Ni identification indépendante de rotors corrélés ni autotuning complet des gains ne sont annoncés.
- Navigation : carte locale déclarée 2D/3D dans le nœud opérations, point relatif, sélection de route et géométrie active distincte du brouillon. Aucun terrain observé sans source réelle.
- Validation : tests natifs des six graphes, sérialisation réelle SNBT/NBT et 96 mouvements synthétiques documentés. À enveloppe inchangée, 32 traces sont identiques à la 0.3.5. Les configurations avec retard important restent en échec dans plusieurs mouvements.

**Le plan complet reste partiellement ouvert** : qualification de toutes les architectures dans Minecraft, identification mécanique instrumentée, commandes de lacet facultatives, garantie de freinage/virage sur route et réutilisation sélective de calibration demandent encore des preuves. Les limites d’API ne sont pas remplacées par des données supposées. Voir [le guide](OPERATIONS.md) et [les résultats complets](reports/operations-physics-0.4.0/README.md).

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

## Correction 0.3.5 : amortissement sous charge suspendue

L’effort vertical reste estimé pendant les oscillations modérées. Le retour horizontal au maintien tient compte de cet effort et le freinage vertical renforcé est réservé aux commandes verticales ou à un effort extérieur significatif. Aucun paramètre de corde, de masse suspendue ou de fréquence supplémentaire. Les [96 essais avec câble](reports/quad-load-0.3.5/README.md) passent de 9/48 à 29/48 succès, avec huit maintiens réussis sur huit, mais des mouvements encore en échec. Le [résumé et les limites](reports/quad-fpv-0.3.5/README.md) conservent le prototype rejeté et les régressions. Le plan A–F reste incomplet ; ces preuves synthétiques ne constituent pas une validation Minecraft.
