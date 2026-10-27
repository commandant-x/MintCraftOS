# Rééquilibrage quad 0.3.5 — charge décentrée

Cette régression vérifie que le contrôleur conserve son estimation de déséquilibre de couple à partir des commandes déjà émises et des accélérations angulaires observées. Il ajuste les bras de levier effectifs dans l’allocation et conserve la consigne verticale. Aucun balayage, aucune impulsion de calibration, aucune lecture fictive du centre de masse. La moyenne de modulation est transportée lors des variations de masse et d’inertie. Le solveur continue d’utiliser toute la famille de répartitions bornées, plutôt que de refuser une répartition de norme minimale négative alors qu’une autre solution existe.

![Ajout puis retrait de charge](load-change-comparison.png)

## Protocole et critères

12 montages × maintien, avance/freinage et avance-gauche × deux versions = 72 scénarios, interpréteur LuaJ réel de Cosmonautics 26.08.307, mécanique indépendante à 200 Hz, contrôle à 20 Hz, 60 s par essai. Source 256 RPM et mêmes transmissions entières 0–15. Les charges ponctuelles modifient réellement masse, centre et tenseur complet selon le théorème des axes parallèles. Seuls la masse et les trois termes diagonaux sont transmis au contrôleur, avec pose et vitesse de l’origine fixe du véhicule ; jamais le centre réel ni les termes croisés. La vitesse exposée est la différence de poses fraîches à 20 Hz.

Une modification instantanée de masse conserve pose, vitesse et vitesse angulaire du châssis, sans impulsion de collision. La rampe est une succession de redistributions de masse suivant cette convention ; ce n’est pas une simulation de déplacement interne avec conservation du moment, ni un solveur de corde ou un essai Minecraft.

Le succès COM requiert la simulation complète, 1 201 observations espacées de 0,05 s, une altitude demandée inchangée, puis après chaque changement/fin de commande : 20 observations successives avec |Vy| ≤0,1 m/s, vitesse horizontale ≤0,2 m/s, inclinaison ≤5° et erreur de hauteur ≤1 m, obtenues en 15 s au plus. Les cinq dernières secondes de chaque épisode doivent aussi conserver hauteur <1 m, inclinaison <5° et RMS des vitesses verticale/horizontale <0,2 m/s. Un mouvement demandé doit produire le déplacement signé attendu. Les anciens critères complets restent publiés séparément dans `historical` ; un succès COM ne les remplace pas. Toutes les excursions figurent ci-dessous.

## Résultats

| Version | Succès COM | Échecs COM | Succès aux anciens critères |
| --- | ---: | ---: | ---: |
| 0.3.4 | 15 | 21 | 14 |
| 0.3.5 | 16 | 20 | 17 |

| Montage | Version | Mouvement | COM | Excursion hauteur max m | Inclinaison max ° | 20 observations stables après chaque épisode (s) | Défauts COM |
| --- | --- | --- | --- | ---: | ---: | --- | --- |
| same-mass-right | baseline | hover | FAIL | 0.38 | 7.74 | 54.60 | measured_stationary20 |
| same-mass-right | baseline | brake | PASS | 0.67 | 24.39 | 6.70 | — |
| same-mass-right | baseline | forward-left | FAIL | 4.20 | 48.12 | 10.00 | all_episode_tails_stable |
| same-mass-right | fixed | hover | FAIL | 0.38 | 7.99 | 6.35 | all_episode_tails_stable |
| same-mass-right | fixed | brake | FAIL | 0.51 | 24.10 | 31.25 | measured_stationary20 |
| same-mass-right | fixed | forward-left | FAIL | 3.92 | 48.07 | 22.70 | measured_stationary20 |
| same-mass-corner | baseline | hover | PASS | 0.79 | 10.04 | 7.60 | — |
| same-mass-corner | baseline | brake | FAIL | 0.95 | 25.71 | 16.50 | measured_stationary20 |
| same-mass-corner | baseline | forward-left | PASS | 0.90 | 22.89 | 14.20 | — |
| same-mass-corner | fixed | hover | PASS | 0.71 | 10.08 | 9.65 | — |
| same-mass-corner | fixed | brake | PASS | 1.16 | 27.15 | 11.85 | — |
| same-mass-corner | fixed | forward-left | FAIL | 0.87 | 24.64 | 16.45 | measured_stationary20 |
| same-mass-reverse | baseline | hover | FAIL | 1.56 | 25.38 | 7.60, —, 7.40 | measured_stationary20 |
| same-mass-reverse | baseline | brake | FAIL | 1.32 | 25.71 | —, —, 5.60 | measured_stationary20, all_episode_tails_stable |
| same-mass-reverse | baseline | forward-left | FAIL | 1.38 | 27.12 | —, 8.40, 5.95 | measured_stationary20, all_episode_tails_stable |
| same-mass-reverse | fixed | hover | PASS | 1.05 | 25.55 | 9.65, 11.25, 5.65 | — |
| same-mass-reverse | fixed | brake | FAIL | 1.16 | 30.28 | —, —, 5.70 | measured_stationary20, all_episode_tails_stable |
| same-mass-reverse | fixed | forward-left | FAIL | 1.14 | 30.53 | —, 13.75, 5.60 | measured_stationary20, all_episode_tails_stable |
| added-load | baseline | hover | PASS | 0.34 | 3.55 | 4.45 | — |
| added-load | baseline | brake | PASS | 0.60 | 19.67 | 8.05 | — |
| added-load | baseline | forward-left | PASS | 0.56 | 28.90 | 6.00 | — |
| added-load | fixed | hover | PASS | 0.33 | 3.55 | 5.30 | — |
| added-load | fixed | brake | PASS | 0.62 | 19.94 | 9.80 | — |
| added-load | fixed | forward-left | PASS | 0.50 | 28.53 | 5.75 | — |
| added-far-and-dropped | baseline | hover | PASS | 0.62 | 10.53 | 10.40, 5.95 | — |
| added-far-and-dropped | baseline | brake | FAIL | 0.95 | 32.85 | —, 6.25 | measured_stationary20, all_episode_tails_stable |
| added-far-and-dropped | baseline | forward-left | FAIL | 14.75 | 55.30 | —, 14.55 | measured_stationary20, all_episode_tails_stable |
| added-far-and-dropped | fixed | hover | PASS | 0.56 | 10.06 | 9.25, 6.20 | — |
| added-far-and-dropped | fixed | brake | FAIL | 1.08 | 34.01 | —, 5.35 | measured_stationary20, all_episode_tails_stable |
| added-far-and-dropped | fixed | forward-left | FAIL | 13.65 | 54.94 | —, 23.00 | measured_stationary20, all_episode_tails_stable |
| initial-unknown-corner | baseline | hover | PASS | 0.87 | 10.65 | 8.80 | — |
| initial-unknown-corner | baseline | brake | FAIL | 1.13 | 21.76 | 16.45 | measured_stationary20 |
| initial-unknown-corner | baseline | forward-left | PASS | 0.87 | 23.48 | 11.20 | — |
| initial-unknown-corner | fixed | hover | PASS | 0.76 | 11.33 | 11.45 | — |
| initial-unknown-corner | fixed | brake | PASS | 0.76 | 21.11 | 14.30 | — |
| initial-unknown-corner | fixed | forward-left | PASS | 0.76 | 21.43 | 12.50 | — |
| moving-load-ramp | baseline | hover | PASS | 0.22 | 4.66 | 6.70 | — |
| moving-load-ramp | baseline | brake | FAIL | 0.87 | 23.11 | 15.55 | measured_stationary20 |
| moving-load-ramp | baseline | forward-left | PASS | 0.74 | 24.06 | 13.70 | — |
| moving-load-ramp | fixed | hover | PASS | 0.21 | 4.66 | 5.25 | — |
| moving-load-ramp | fixed | brake | PASS | 0.91 | 23.29 | 12.55 | — |
| moving-load-ramp | fixed | forward-left | PASS | 0.72 | 20.76 | 12.85 | — |
| six-sails-corner | baseline | hover | FAIL | 0.70 | 9.62 | — | measured_stationary20, all_episode_tails_stable |
| six-sails-corner | baseline | brake | FAIL | 0.91 | 34.21 | — | measured_stationary20, all_episode_tails_stable |
| six-sails-corner | baseline | forward-left | FAIL | 0.81 | 29.16 | — | measured_stationary20, all_episode_tails_stable |
| six-sails-corner | fixed | hover | FAIL | 0.63 | 10.06 | — | measured_stationary20, all_episode_tails_stable |
| six-sails-corner | fixed | brake | FAIL | 1.18 | 33.35 | — | measured_stationary20, all_episode_tails_stable |
| six-sails-corner | fixed | forward-left | FAIL | 0.78 | 28.07 | — | measured_stationary20, all_episode_tails_stable |
| heavy-with-added-load | baseline | hover | PASS | 0.22 | 4.01 | 3.15 | — |
| heavy-with-added-load | baseline | brake | PASS | 0.55 | 20.33 | 7.40 | — |
| heavy-with-added-load | baseline | forward-left | PASS | 0.59 | 31.90 | 6.70 | — |
| heavy-with-added-load | fixed | hover | PASS | 0.22 | 4.02 | 3.05 | — |
| heavy-with-added-load | fixed | brake | PASS | 0.57 | 20.17 | 8.10 | — |
| heavy-with-added-load | fixed | forward-left | PASS | 0.58 | 31.58 | 6.65 | — |
| mixed-sails-corner | baseline | hover | PASS | 0.75 | 9.78 | 13.55 | — |
| mixed-sails-corner | baseline | brake | FAIL | 1.07 | 21.09 | 21.25 | measured_stationary20 |
| mixed-sails-corner | baseline | forward-left | FAIL | 1.10 | 19.94 | 15.45 | measured_stationary20 |
| mixed-sails-corner | fixed | hover | FAIL | 0.65 | 9.38 | 32.40 | measured_stationary20 |
| mixed-sails-corner | fixed | brake | FAIL | 0.95 | 21.85 | 25.35 | measured_stationary20 |
| mixed-sails-corner | fixed | forward-left | FAIL | 0.80 | 19.28 | 21.55 | measured_stationary20 |
| delayed-noisy-right | baseline | hover | FAIL | 3.51 | 34.01 | — | measured_stationary20, all_episode_tails_stable |
| delayed-noisy-right | baseline | brake | FAIL | 118.37 | 70.52 | — | measured_stationary20, all_episode_tails_stable |
| delayed-noisy-right | baseline | forward-left | FAIL | 3.46 | 40.96 | — | measured_stationary20, all_episode_tails_stable, motion_observed |
| delayed-noisy-right | fixed | hover | FAIL | 5.54 | 40.35 | — | measured_stationary20, all_episode_tails_stable |
| delayed-noisy-right | fixed | brake | FAIL | 64.47 | 65.80 | — | measured_stationary20, all_episode_tails_stable |
| delayed-noisy-right | fixed | forward-left | FAIL | 4.42 | 40.89 | — | measured_stationary20, all_episode_tails_stable, motion_observed |
| outside-physical-support | baseline | hover | FAIL | 62.10 | 104.99 | — | measured_stationary20, all_episode_tails_stable |
| outside-physical-support | baseline | brake | FAIL | 28.23 | 97.90 | — | measured_stationary20, all_episode_tails_stable, motion_observed |
| outside-physical-support | baseline | forward-left | FAIL | 236.70 | 101.86 | — | measured_stationary20, all_episode_tails_stable, motion_observed |
| outside-physical-support | fixed | hover | FAIL | 22.15 | 105.76 | — | measured_stationary20, all_episode_tails_stable |
| outside-physical-support | fixed | brake | FAIL | 78.56 | 102.76 | — | measured_stationary20, all_episode_tails_stable, motion_observed |
| outside-physical-support | fixed | forward-left | FAIL | 73.84 | 96.98 | — | measured_stationary20, all_episode_tails_stable, motion_observed |

## Limites

Le centre hors du polygone des hélices est volontairement irréalisable et reste un échec. Les montages avec forte hétérogénéité, délais, faibles marges de poussée ou changement pendant une manœuvre peuvent conserver des excursions et des échecs. L’estimation est un biais effectif : elle ne prouve pas un centre de masse mesuré ou une pale disparue. La position fournie par Sputnik n’est pas garantie au centre de masse ; sa rotation peut affecter l’altitude affichée. L’effort vertical est désormais appris pendant les oscillations modérées avec son filtrage conservé, afin de ne pas bloquer l’adaptation à une charge suspendue. Une erreur de modèle peut encore contaminer cette estimation.

Le maintien ne peut être garanti pendant un retournement ou si la charge dépasse l’autorité disponible. Les autres architectures et le contrôleur standard ne sont pas modifiés. Voir aussi la [campagne de non-régression](../quad-campaign-0.3.5/README.md).

## Reproduction

`tools/test-sputnik-quad-com.py --help`, puis `tools/report-sputnik-quad-com.py` et `tools/verify-sputnik-quad-com.py`. Le fichier Lua 0.3.4 de référence doit être fourni explicitement. Les deux sources réellement exécutées, les critères et la mécanique sont gelés dans l’archive. La validation distincte de l’import SNBT/LuaJ est consignée dans le résumé de livraison.
