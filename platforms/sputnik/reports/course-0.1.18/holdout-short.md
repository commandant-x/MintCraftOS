# Sputnik 0.1.18 — banc numérique 3D

**Simulation indépendante paramétrée ; pas un jumeau mesuré du véhicule du joueur.**

Cas de référence réussis : **12/12**. Les cas « stress » modifient volontairement les hypothèses du contrôleur ; ils ne sont pas exclus des résultats.

Les véritables scripts Lua livrés sont exécutés dans le LuaJ de Cosmonautics. La plante utilise quaternion, forces aux quatre points, couples et inerties, dynamique rigide à 200 Hz, régime retardé à 20 Hz et propagation du graphe à un tick. La plante continue après un défaut : le repli ne fige pas le véhicule.

Critères : actif tout le long, erreur finale altitude < 0,3 m, vitesse finale < 0,2 m/s, erreur horizontale finale < 0,3 m et inclinaison maximale < 25°. Sur les dix dernières secondes : inclinaison RMS < 2° et vitesse RMS < 0,2 m/s. Une réussite ne borne pas les excursions transitoires : elles sont indiquées séparément.

| Scénario | Stress | Résultat | Erreur finale (m) | Inclinaison max (°) | RMS angle (°) | RMS vitesse (m/s) | T1 (s) | Défaut |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| level_hover | false | PASS | 0.011 | 0.00 | 0.000 | 0.014 | -1.00 | — |
| level_drop_5ms | false | PASS | 0.054 | 0.00 | 0.000 | 0.024 | -1.00 | — |
| tilt_yaw_90deg | false | PASS | 0.004 | 5.00 | 0.208 | 0.040 | -1.00 | — |
| forward_then_brake | false | PASS | 0.000 | 6.82 | 0.078 | 0.018 | 1.65 | — |
| diagonal_then_brake | false | PASS | 0.001 | 4.97 | 0.072 | 0.010 | -1.00 | — |
| radio_delay_4ticks | false | PASS | 0.025 | 4.99 | 0.070 | 0.112 | -1.00 | — |
| inertia_quarter | false | PASS | 0.006 | 4.99 | 0.173 | 0.020 | -1.00 | — |
| inertia_eighth | false | PASS | 0.001 | 4.98 | 0.358 | 0.026 | -1.00 | — |
| reverse_every_half_second | false | PASS | 0.001 | 2.71 | 0.070 | 0.016 | -1.00 | — |
| periodic_pitch_05hz | false | PASS | 0.002 | 3.71 | 0.107 | 0.027 | -1.00 | — |
| course_left_arc | false | PASS | 0.000 | 8.03 | 0.067 | 0.010 | 1.65 | — |
| course_release_steer | false | PASS | 0.004 | 8.15 | 0.063 | 0.012 | 1.65 | — |

Paramètres de base : 65 kg, inerties diagonales supposées 250/400/230 kg·m², demi-largeur 3 m, demi-longueur 2 m, rotors à +1 m de Sputnik, altitude initiale Y=80, centre de masse centré, petits rotors identiques vers le haut, 256 RPM, gravité 11, retard radio 1 tick. Les amortissements 0,05 s⁻¹ sont hypothétiques ; un cas les supprime complètement.

Les signaux 0..15 sont des réductions : 0 = 256 RPM, 1 = 224 RPM et 15 = arrêt. Les traces CSV contiennent les signaux réellement appliqués par la plante et les quatre régimes.

RMS : moyenne quadratique sur les dix dernières secondes. T1 : délai depuis l’appui W pour atteindre 1 m/s vers l’avant ; −1 signifie non atteint pendant l’appui ou non applicable. L’erreur maximale transitoire reste disponible dans le CSV.

La masse et les dimensions sont des paramètres déclarés ; les inerties, le centre de masse et la mécanique ne sont pas mesurés. Le moteur physique Sable et le réseau cinétique Create ne sont pas lancés. Aucune certitude de vol en jeu ni qualification autopilote ne résulte de ce rapport.

Contrôleur SHA256 : `71a9dd3537679b057e5a266eb55ae006db0c586baa2442e9e31a0a9c229bae7b`.
Plante SHA256 : `4db83fd13af13e7aa1d385ae9e6baedb963b8bd0f39012c93cb7d86c9338d857`.
