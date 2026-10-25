# Sputnik 0.1.20 — banc numérique 3D

**Simulation indépendante paramétrée ; pas un jumeau mesuré du véhicule du joueur.**

Cas de référence réussis : **36/41**. Les cas « stress » modifient volontairement les hypothèses du contrôleur ; ils ne sont pas exclus des résultats.

Les véritables scripts Lua livrés sont exécutés dans le LuaJ de Cosmonautics. La plante utilise quaternion, forces aux quatre points, couples et inerties, dynamique rigide à 200 Hz, régime retardé à 20 Hz et propagation du graphe à un tick. La plante continue après un défaut : le repli ne fige pas le véhicule.

Critères : actif tout le long, erreur finale altitude < 0,3 m, vitesse finale < 0,2 m/s, erreur horizontale finale < 0,3 m et inclinaison maximale < 25°. Sur les dix dernières secondes : inclinaison RMS < 2° et vitesse RMS < 0,2 m/s. Une réussite ne borne pas les excursions transitoires : elles sont indiquées séparément.

| Scénario | Stress | Résultat | Erreur finale (m) | Inclinaison max (°) | RMS angle (°) | RMS vitesse (m/s) | T1 (s) | Défaut |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| level_hover | false | PASS | 0.007 | 0.00 | 0.000 | 0.027 | -1.00 | — |
| level_drop_2ms | false | PASS | 0.002 | 0.00 | 0.000 | 0.029 | -1.00 | — |
| level_drop_5ms | false | PASS | 0.000 | 0.00 | 0.000 | 0.029 | -1.00 | — |
| cold_rotors | false | PASS | 0.006 | 0.00 | 0.000 | 0.030 | -1.00 | — |
| tilt_pitch_5deg | false | PASS | 0.008 | 5.00 | 0.064 | 0.022 | -1.00 | — |
| tilt_roll_5deg | false | PASS | 0.005 | 4.97 | 0.082 | 0.021 | -1.00 | — |
| tilt_yaw_90deg | false | PASS | 0.014 | 4.99 | 0.065 | 0.016 | -1.00 | — |
| space_then_hold | false | PASS | 0.008 | 0.00 | 0.000 | 0.023 | -1.00 | — |
| forward_then_brake | false | PASS | 0.003 | 12.04 | 0.058 | 0.026 | 1.10 | — |
| diagonal_then_brake | false | PASS | 0.006 | 11.26 | 0.064 | 0.017 | -1.00 | — |
| mass_loss_15percent | false | PASS | 0.001 | 0.00 | 0.000 | 0.026 | -1.00 | — |
| no_airframe_drag | false | PASS | 0.004 | 12.30 | 0.049 | 0.018 | 1.10 | — |
| radio_delay_2ticks | false | PASS | 0.004 | 13.48 | 0.065 | 0.019 | 1.15 | — |
| radio_delay_4ticks | false | FAIL | 0.035 | 6.44 | 2.580 | 0.582 | -1.00 | — |
| heavy_85kg | false | PASS | 0.003 | 0.00 | 0.000 | 0.015 | -1.00 | — |
| light_40kg | false | PASS | 0.004 | 0.00 | 0.000 | 0.030 | -1.00 | — |
| noise_position_2cm | false | PASS | 0.004 | 0.16 | 0.056 | 0.017 | -1.00 | — |
| gust_1ms | false | PASS | 0.030 | 5.15 | 0.099 | 0.025 | -1.00 | — |
| inertia_quarter | false | FAIL | 0.004 | 5.00 | 1.019 | 0.203 | -1.00 | — |
| inertia_fourfold | false | PASS | 0.009 | 4.99 | 0.241 | 0.069 | -1.00 | — |
| sustained_forward | false | PASS | 0.035 | 13.94 | 0.060 | 0.024 | 1.10 | — |
| reverse_every_second | false | PASS | 0.076 | 13.33 | 0.053 | 0.042 | -1.00 | — |
| reverse_every_half_second | false | PASS | 0.022 | 6.01 | 0.084 | 0.027 | -1.00 | — |
| periodic_pitch_05hz | false | PASS | 0.008 | 2.01 | 0.073 | 0.017 | -1.00 | — |
| periodic_roll_1hz | false | PASS | 0.005 | 1.29 | 0.069 | 0.020 | -1.00 | — |
| attitude_noise_01deg | false | PASS | 0.012 | 4.99 | 0.100 | 0.018 | -1.00 | — |
| inertia_eighth | false | FAIL | 0.028 | 11.02 | 6.700 | 3.067 | -1.00 | — |
| inertia_quarter_delay2 | false | FAIL | 0.320 | 10.62 | 6.411 | 1.531 | -1.00 | — |
| held_forward_20s | false | PASS | 0.006 | 16.57 | 0.056 | 0.023 | 1.10 | — |
| held_forward_no_drag | false | PASS | 0.002 | 19.00 | 0.084 | 0.019 | 1.10 | — |
| held_forward_tilt15 | false | FAIL | 130.494 | 34.30 | inf | inf | 0.90 | FAULT: Near-level attitude envelope exceeded / pitch=-25.32657532006826 roll=0.0 MODULAIRE m=32.0 |
| held_forward_heavy | true | PASS | 0.002 | 14.02 | 0.094 | 0.009 | 1.15 | — |
| held_forward_endurance | true | FAIL | 132.363 | 179.86 | inf | inf | 1.10 | FAULT: Near-level attitude envelope exceeded / pitch=25.932954701550564 roll=0.0 MODULAIRE m=32.0 / RADIO_3: demande 0 reseau 2 |
| travel_mass_loss | false | PASS | 0.001 | 17.46 | 0.063 | 0.015 | 1.10 | — |
| course_left_arc | false | PASS | 0.006 | 12.47 | 0.067 | 0.013 | 1.10 | — |
| course_right_arc | false | PASS | 0.006 | 12.47 | 0.067 | 0.013 | 1.10 | — |
| course_no_drag | false | PASS | 0.001 | 22.94 | 0.065 | 0.013 | 1.10 | — |
| course_release_steer | false | PASS | 0.009 | 11.11 | 0.077 | 0.014 | 1.10 | — |
| course_turn_only | false | PASS | 0.019 | 11.11 | 0.056 | 0.013 | 1.10 | — |
| steer_at_rest | false | PASS | 0.009 | 0.00 | 0.000 | 0.024 | -1.00 | — |
| classic_strafe | false | PASS | 0.014 | 11.72 | 0.065 | 0.018 | -1.00 | — |
| course_straight_gust | false | PASS | 0.013 | 17.63 | 0.061 | 0.014 | 1.10 | — |
| course_reverse_arc | false | PASS | 0.006 | 12.47 | 0.067 | 0.013 | -1.00 | — |
| slow_spool | true | PASS | 0.002 | 4.99 | 0.051 | 0.014 | -1.00 | — |
| com_offset_10cm | true | FAIL | 0.003 | 0.64 | 0.097 | 0.024 | -1.00 | — |
| com_offset_25cm | true | FAIL | 0.003 | 1.71 | 0.107 | 0.024 | -1.00 | — |
| rotor_weak_10percent | true | FAIL | 0.003 | 0.84 | 0.063 | 0.016 | -1.00 | — |
| swapped_front_rear | true | FAIL | 130.395 | 61.66 | 61.286 | 43.201 | -1.00 | FAULT: Near-level attitude envelope exceeded / pitch=27.064768574860484 roll=0.0 MODULAIRE m=32.0 |
| competing_tx_15 | true | FAIL | 132.155 | 168.23 | 161.309 | 42.186 | -1.00 | FAULT: Near-level attitude envelope exceeded / pitch=21.231599673661336 roll=25.06811858389965 MODULAIRE m=32.0 / RADIO_1: demande 13 reseau 15 |
| reversed_transmission | true | FAIL | 130.836 | 0.00 | 0.000 | 47.499 | -1.00 | — |

Paramètres de base : 32 kg, inerties diagonales supposées 250/400/230 kg·m², demi-largeur 3 m, demi-longueur 5 m, rotors à +1 m de Sputnik, altitude initiale Y=80, centre de masse centré, petits rotors identiques vers le haut, 256 RPM, gravité 11, retard radio 1 tick. Les amortissements 0,05 s⁻¹ sont hypothétiques ; un cas les supprime complètement.

Les signaux 0..15 sont des réductions : 0 = 256 RPM, 1 = 224 RPM et 15 = arrêt. Les traces CSV contiennent les signaux réellement appliqués par la plante et les quatre régimes.

RMS : moyenne quadratique sur les dix dernières secondes. T1 : délai depuis l’appui W pour atteindre 1 m/s vers l’avant ; −1 signifie non atteint pendant l’appui ou non applicable. L’erreur maximale transitoire reste disponible dans le CSV.

La masse et les dimensions sont des paramètres déclarés ; les inerties, le centre de masse et la mécanique ne sont pas mesurés. Le moteur physique Sable et le réseau cinétique Create ne sont pas lancés. Aucune certitude de vol en jeu ni qualification autopilote ne résulte de ce rapport.

Contrôleur SHA256 : `39ae1aee4b68ca2aa7ecbf2aa33a7ea73a7172c9dd87b25a575718ee5a76de7c`.
Plante SHA256 : `54e5e5dfa4877a870c9827c15e86e87a1ed6da7d37d2e8427ab102112b3ef493`.
