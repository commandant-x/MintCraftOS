# Autopilot graphique — 0.18.79

**Navigation → Autopilot**, ou le bouton **Autopilot** en haut de Flight,
ouvre désormais le tableau de pilotage. Ouvrir cet écran ne lance aucun test.
La vue **Route** conserve l'accès aux routes avancées.

Après la préparation automatique, Navigation affiche directement ce tableau.
La préparation ne se relance que par **Calibrer**, après confirmation des mouvements.

## Maintenir une hauteur

- Lire l'altitude mesurée et la vitesse verticale.
- Choisir l'altitude cible avec **−10 m / −1 m / +1 m / +10 m**, **Ici**,
  ou **Saisir** (clavier physique ou graphique, décimales acceptées).
- Cliquer **Maintenir cette altitude**. Modifier la valeur seule ne commande rien.
- Le tableau montre la consigne appliquée, l'erreur et la plage d'altitude mesurée.

La table issue de la calibration transforme la hauteur demandée en chauffe moyenne.
Le retour altitude/vitesse verticale corrige cette moyenne. Le contrôleur alterne
entre les deux niveaux redstone adjacents à la chauffe corrigée ; le tableau montre
ces niveaux, leur proportion haute et le signal réellement envoyé. Chaque évolution
de l'alternance attend un nouveau retour des récepteurs. La cadence dépend du retour
réel, et ne repose pas sur un changement aveugle toutes les N secondes.
Les deux niveaux peuvent évoluer pendant la montée ou le freinage. La consigne reste
dans la plage mesurée, sans extrapolation. La précision réelle dépend du montage,
de l'inertie thermique et de la cadence du serveur : aucune précision absolue garantie.

Sur un écran étroit, faire défiler pour atteindre les boutons inférieurs.
**STOP / F10** reste toujours accessible, même pendant la saisie d'une valeur invalide.
Fermer Navigation arrête le pilotage et applique le secours.

## Atlas intégré : destination X/Z

Ouvrir **Atlas**, puis cliquer sur la carte. Le point correspond à des coordonnées
monde calculées depuis la position réelle du véhicule ; +Z est vers le bas. Les
boutons Zoom changent les mètres par pixel. La carte est un sélecteur X/Z sans
relief, sans lecture de chunks et sans évitement d'obstacles.

**Suivre destination** affiche la destination et l'altitude choisie. Seul le bouton
**Confirmer trajet dégagé** lance le trajet. L'altitude monde est convertie en hauteur
d'origine Sable à partir d'une mesure fraîche, puis le service applique les mêmes
contrôles de permissions, d'identité, de calibration et de retour des moteurs que
pour une route avancée. Changer de véhicule efface la sélection de carte.

Un ballon sans direction horizontale mesurée conserve le maintien vertical ; la
carte ne lui invente pas une capacité à rejoindre une destination. Le trajet exige
la calibration réelle des groupes moteurs indépendants. La vitesse utilise la
consigne positive saisie dans Saisir, ou par défaut au plus 1 m/s dans la plage
mesurée. F10 applique le secours ; l'atterrissage reste manuel.

Validation : tests du tableau natif, de la saisie jusqu'à l'API de contrôle, du clic
carte jusqu'au trajet et de sa conversion d'altitude, du refus sans autorité
horizontale, du changement de véhicule, de STOP et de l'affichage de chauffe
provenant du contrôleur. Les tests physiques utilisent un modèle simulé.
