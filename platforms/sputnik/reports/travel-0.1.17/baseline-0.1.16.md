# Sputnik 0.1.16 — banc numérique 3D

**Simulation indépendante paramétrée ; pas un jumeau mesuré du véhicule du joueur.**

Cas de référence réussis : **28/32**. Les cas « stress » modifient volontairement les hypothèses du contrôleur ; ils ne sont pas exclus des résultats.

Les véritables scripts Lua livrés sont exécutés dans le LuaJ de Cosmonautics. La plante utilise quaternion, forces aux quatre points, couples et inerties, dynamique rigide à 200 Hz, régime retardé à 20 Hz et propagation du graphe à un tick. La plante continue après un défaut : le repli ne fige pas le véhicule.

Critères : actif tout le long, erreur finale altitude < 0,3 m, vitesse finale < 0,2 m/s, erreur horizontale finale < 0,3 m et inclinaison maximale < 25°. Sur les dix dernières secondes : inclinaison RMS < 2° et vitesse RMS < 0,2 m/s. Une réussite ne borne pas les excursions transitoires : elles sont indiquées séparément.

| Scénario | Stress | Résultat | Erreur finale (m) | Inclinaison max (°) | RMS angle (°) | RMS vitesse (m/s) | T1 (s) | Défaut |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| level_hover | false | PASS | 0.003 | 0.00 | 0.000 | 0.007 | -1.00 | — |
| level_drop_2ms | false | PASS | 0.008 | 0.00 | 0.000 | 0.007 | -1.00 | — |
| level_drop_5ms | false | PASS | 0.024 | 0.00 | 0.000 | 0.009 | -1.00 | — |
| cold_rotors | false | PASS | 0.011 | 0.00 | 0.000 | 0.008 | -1.00 | — |
| tilt_pitch_5deg | false | PASS | 0.001 | 4.99 | 0.027 | 0.005 | -1.00 | — |
| tilt_roll_5deg | false | PASS | 0.002 | 5.00 | 0.054 | 0.013 | -1.00 | — |
| tilt_yaw_90deg | false | PASS | 0.003 | 4.99 | 0.039 | 0.008 | -1.00 | — |
| space_then_hold | false | PASS | 0.009 | 0.00 | 0.000 | 0.014 | -1.00 | — |
| forward_then_brake | false | PASS | 0.005 | 8.64 | 0.033 | 0.005 | 1.40 | — |
| diagonal_then_brake | false | PASS | 0.005 | 10.68 | 0.064 | 0.012 | -1.00 | — |
| mass_loss_15percent | false | PASS | 0.015 | 0.00 | 0.000 | 0.029 | -1.00 | — |
| no_airframe_drag | false | PASS | 0.003 | 8.76 | 0.032 | 0.006 | 1.35 | — |
| radio_delay_2ticks | false | PASS | 0.003 | 8.94 | 0.026 | 0.006 | 1.40 | — |
| radio_delay_4ticks | false | PASS | 0.002 | 4.99 | 0.035 | 0.005 | -1.00 | — |
| heavy_85kg | false | PASS | 0.002 | 0.00 | 0.000 | 0.007 | -1.00 | — |
| light_40kg | false | PASS | 0.002 | 0.00 | 0.000 | 0.005 | -1.00 | — |
| noise_position_2cm | false | PASS | 0.000 | 0.08 | 0.027 | 0.007 | -1.00 | — |
| gust_1ms | false | PASS | 0.003 | 4.69 | 0.032 | 0.008 | -1.00 | — |
| inertia_quarter | false | PASS | 0.000 | 4.97 | 0.095 | 0.004 | -1.00 | — |
| inertia_fourfold | false | PASS | 0.002 | 4.99 | 0.057 | 0.014 | -1.00 | — |
| sustained_forward | false | PASS | 0.005 | 8.71 | 0.053 | 0.008 | 1.40 | — |
| reverse_every_second | false | PASS | 0.012 | 7.57 | 0.031 | 0.007 | -1.00 | — |
| reverse_every_half_second | false | PASS | 0.005 | 4.04 | 0.040 | 0.007 | -1.00 | — |
| periodic_pitch_05hz | false | PASS | 0.008 | 3.29 | 0.021 | 0.006 | -1.00 | — |
| periodic_roll_1hz | false | PASS | 0.002 | 1.51 | 0.033 | 0.007 | -1.00 | — |
| attitude_noise_01deg | false | PASS | 0.005 | 4.99 | 0.057 | 0.008 | -1.00 | — |
| inertia_eighth | false | PASS | 0.001 | 4.97 | 0.131 | 0.006 | -1.00 | — |
| inertia_quarter_delay2 | false | PASS | 0.001 | 4.98 | 0.067 | 0.005 | -1.00 | — |
| held_forward_20s | false | FAIL | 0.000 | 8.73 | 0.025 | 0.004 | 1.40 | — |
| held_forward_no_drag | false | FAIL | 0.002 | 8.67 | 0.025 | 0.005 | 1.35 | — |
| held_forward_tilt15 | false | FAIL | 0.001 | 10.76 | 0.024 | 0.006 | 1.30 | — |
| held_forward_heavy | true | FAIL | 0.002 | 9.66 | 1.219 | 0.507 | 1.75 | — |
| held_forward_endurance | true | FAIL | 0.000 | 8.78 | 0.026 | 0.005 | 1.35 | — |
| travel_mass_loss | false | FAIL | 0.002 | 9.06 | 0.132 | 0.022 | 1.40 | — |
| slow_spool | true | PASS | 0.001 | 4.99 | 0.013 | 0.004 | -1.00 | — |
| com_offset_10cm | true | FAIL | 0.002 | 1.56 | 0.025 | 0.006 | -1.00 | — |
| com_offset_25cm | true | FAIL | 0.005 | 3.82 | 0.066 | 0.011 | -1.00 | — |
| rotor_weak_10percent | true | FAIL | 0.007 | 2.05 | 0.041 | 0.007 | -1.00 | — |
| swapped_front_rear | true | FAIL | 130.291 | 89.21 | 88.972 | 43.780 | -1.00 | FAULT: Near-level attitude envelope exceeded / pitch=26.562234631023944 roll=0.0 m=32.0 |
| competing_tx_15 | true | FAIL | 130.148 | 156.73 | 79.811 | 43.084 | -1.00 | FAULT: Near-level attitude envelope exceeded / pitch=25.62388143261298 roll=20.349300793028362 m=32.0 / RADIO_1: demande 0 reseau 15 |
| reversed_transmission | true | FAIL | 85.341 | 0.00 | 0.000 | 7.161 | -1.00 | — |

Paramètres de base : 32 kg, inerties diagonales supposées 250/400/230 kg·m², demi-largeur 3 m, demi-longueur 5 m, rotors à +1 m de Sputnik, altitude initiale Y=80, centre de masse centré, petits rotors identiques vers le haut, 256 RPM, gravité 11, retard radio 1 tick. Les amortissements 0,05 s⁻¹ sont hypothétiques ; un cas les supprime complètement.

Les signaux 0..15 sont des réductions : 0 = 256 RPM, 1 = 224 RPM et 15 = arrêt. Les traces CSV contiennent les signaux réellement appliqués par la plante et les quatre régimes.

RMS : moyenne quadratique sur les dix dernières secondes. T1 : délai depuis l’appui W pour atteindre 1 m/s vers l’avant ; −1 signifie non atteint pendant l’appui ou non applicable. L’erreur maximale transitoire reste disponible dans le CSV.

La masse et les dimensions sont des paramètres déclarés ; les inerties, le centre de masse et la mécanique ne sont pas mesurés. Le moteur physique Sable et le réseau cinétique Create ne sont pas lancés. Aucune certitude de vol en jeu ni qualification autopilote ne résulte de ce rapport.

Contrôleur SHA256 : `d9b4c31aec0be26c85e624d0001591fb139f4eb86558addd5b071d2e8957c3d6`.
Plante SHA256 : `520ef88f8ddee0d46a265fcc5b78e7682f67f824ad91847d5b100e88f6a3a96c`.
