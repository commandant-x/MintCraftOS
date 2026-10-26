# Correction de modulation 0.3.3 : résultats et limites

**Le matériel reste inchangé : 256 RPM et transmissions 0–15.** Un raccourci qui effaçait les faibles différences et le résidu de couple près du maintien est supprimé. Les gains et les modèles sont identiques ; le test de moyenne des couples signés échoue avant correction et réussit après.

## Les critères de transition montrent l’effet principal

Sur les mêmes 552 traces exécutées, le nouveau diagnostic de stabilité durable est atteint en au plus 8 s dans **346 cas**, contre **251** en 0.3.2. Le nombre sans seconde terminale entière dans les bandes passe de **100 à 64**. Ces bandes plus strictes restent celles de la recherche précédente : hauteur 0,3 m, assiette 2°, Vy 0,2 m/s, Vh 0,3 m/s après déplacement. Il ne s’agit pas d’un plafond de vitesse en vol.

Les données sont dans [transients.json](transients.json), les anciennes mesures dans [la recherche 0.3.2](../quad-ringing-0.3.2/native-campaign-transients.json). Les anciens critères ne sont pas réécrits pour transformer une transition lente en réussite rapide.

Le départ incliné à 3° est testé séparément dans le vrai LuaJ : maintien **33,70 → 0,95 s**, freinage **46,60 → 5,95 s**, perturbation diagonale **51,10 → 4,20 s**. Le régime source reste réellement 256 RPM dans les deux bancs. Voir [les 82 classifications comparées](../quad-pwm-0.3.3/README.md), dont 80 scénarios physiques et deux refus prévol conservés.

## Anciens critères de campagne : amélioration non uniforme

**394 PASS / 158 FAIL / 24 REFUSED** sur 576 cellules. La version précédente donnait 393/159/24. Neuf anciens échecs deviennent des réussites, mais huit anciennes réussites régressent. Ce nombre presque inchangé ne reflète pas à lui seul la réduction du temps de stabilisation. Il reste aussi des échecs dynamiques substantiels.

| Avant | Après | Nombre |
| --- | --- | ---: |
| FAIL | FAIL | 150 |
| FAIL | PASS | 9 |
| PASS | FAIL | 8 |
| PASS | PASS | 385 |
| REFUSED | REFUSED | 24 |

Référence à plat : 24/24 ; référence inclinée à 3° : 24/24 contre 23/24 avant correction. Les essais inversés peuvent perdre environ **10,97 m** ; la récupération d’assiette est mesurée à **6,75 s** sur la référence à plat, tandis que le retour durable dans toutes les bandes peut prendre davantage de temps.

## Régressions conservées

| Configuration | Mouvement | Critères échoués |
| --- | --- | --- |
| light-16kg | turn-left | active_height |
| light-16kg | turn-right | active_height |
| low-inertia | climb-forward | braking |
| narrow | left | transient_tilt |
| narrow | right | transient_tilt |
| paired-rotors | turn-left | active_height |
| paired-rotors | turn-right | active_height |
| telemetry-delay | reverse-left | braking |

Les grands retards radio, la très faible inertie, certains montages étroits et la forte poussée relative à la masse restent des travaux ouverts. Le profil rapide demeure expérimental. Aucun essai Minecraft n’est revendiqué.

## Portée du changement

Une comparaison des sources lisibles vérifie que seul `Vehicle.signals` change : préfixe et suffixe sont identiques. Régime source, modèles, géométrie, filtres, observateurs et gains sont conservés. La modulation étudie désormais les 16 combinaisons de niveaux à chaque appel, y compris en maintien ; la borne de calcul est identique à celle auparavant utilisée pendant les demandes différentielles. La latence serveur réelle n’est pas garantie par le banc.

Le quantificateur conserve les petites corrections sous forme de moyenne temporelle. Les moteurs peuvent alterner des niveaux différents ; une alternance visible ne prouve donc pas à elle seule une oscillation du véhicule. Les courbes de pose, de vitesse et de cible déterminent la stabilité.

## Preuves

[Sources et traces gelées](README.md) · [Régression native à source fixe](../quad-pwm-0.3.3/README.md) · [Sensibilité 200/400 Hz](convergence/README.md). Les résultats de la référence ne qualifient pas les autres géométries ; les autres architectures utilisent leur contrôleur inchangé.
