# Sputnik 0.1.17 — banc numérique 3D

**Simulation indépendante paramétrée ; pas un jumeau mesuré du véhicule du joueur.**

Cas de référence réussis : **10/10**. Les cas « stress » modifient volontairement les hypothèses du contrôleur ; ils ne sont pas exclus des résultats.

Les véritables scripts Lua livrés sont exécutés dans le LuaJ de Cosmonautics. La plante utilise quaternion, forces aux quatre points, couples et inerties, dynamique rigide à 200 Hz, régime retardé à 20 Hz et propagation du graphe à un tick. La plante continue après un défaut : le repli ne fige pas le véhicule.

Critères : actif tout le long, erreur finale altitude < 0,3 m, vitesse finale < 0,2 m/s, erreur horizontale finale < 0,3 m et inclinaison maximale < 25°. Sur les dix dernières secondes : inclinaison RMS < 2° et vitesse RMS < 0,2 m/s. Une réussite ne borne pas les excursions transitoires : elles sont indiquées séparément.

| Scénario | Stress | Résultat | Erreur finale (m) | Inclinaison max (°) | RMS angle (°) | RMS vitesse (m/s) | T1 (s) | Défaut |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| level_hover | false | PASS | 0.011 | 0.00 | 0.000 | 0.014 | -1.00 | — |
| level_drop_5ms | false | PASS | 0.054 | 0.00 | 0.000 | 0.024 | -1.00 | — |
| tilt_yaw_90deg | false | PASS | 0.004 | 5.00 | 0.208 | 0.040 | -1.00 | — |
| forward_then_brake | false | PASS | 0.001 | 6.81 | 0.048 | 0.014 | 1.70 | — |
| diagonal_then_brake | false | PASS | 0.003 | 7.07 | 0.060 | 0.012 | -1.00 | — |
| radio_delay_4ticks | false | PASS | 0.025 | 4.99 | 0.070 | 0.112 | -1.00 | — |
| inertia_quarter | false | PASS | 0.006 | 4.99 | 0.173 | 0.020 | -1.00 | — |
| inertia_eighth | false | PASS | 0.001 | 4.98 | 0.358 | 0.026 | -1.00 | — |
| reverse_every_half_second | false | PASS | 0.001 | 2.78 | 0.057 | 0.015 | -1.00 | — |
| periodic_pitch_05hz | false | PASS | 0.002 | 3.71 | 0.107 | 0.027 | -1.00 | — |

Paramètres de base : 65 kg, inerties diagonales supposées 250/400/230 kg·m², demi-largeur 3 m, demi-longueur 2 m, rotors à +1 m de Sputnik, altitude initiale Y=80, centre de masse centré, petits rotors identiques vers le haut, 256 RPM, gravité 11, retard radio 1 tick. Les amortissements 0,05 s⁻¹ sont hypothétiques ; un cas les supprime complètement.

Les signaux 0..15 sont des réductions : 0 = 256 RPM, 1 = 224 RPM et 15 = arrêt. Les traces CSV contiennent les signaux réellement appliqués par la plante et les quatre régimes.

RMS : moyenne quadratique sur les dix dernières secondes. T1 : délai depuis l’appui W pour atteindre 1 m/s vers l’avant ; −1 signifie non atteint pendant l’appui ou non applicable. L’erreur maximale transitoire reste disponible dans le CSV.

La masse et les dimensions sont des paramètres déclarés ; les inerties, le centre de masse et la mécanique ne sont pas mesurés. Le moteur physique Sable et le réseau cinétique Create ne sont pas lancés. Aucune certitude de vol en jeu ni qualification autopilote ne résulte de ce rapport.

Contrôleur SHA256 : `40bcdc1453a1a1de6e581cfbf45efe1c796ab8f2652c3688943fec0819b4e452`.
Plante SHA256 : `520ef88f8ddee0d46a265fcc5b78e7682f67f824ad91847d5b100e88f6a3a96c`.
