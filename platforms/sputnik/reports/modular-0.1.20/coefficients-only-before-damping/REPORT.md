# Sputnik 0.1.20 — banc numérique 3D

**Simulation indépendante paramétrée ; pas un jumeau mesuré du véhicule du joueur.**

Cas de référence réussis : **28/41**. Les cas « stress » modifient volontairement les hypothèses du contrôleur ; ils ne sont pas exclus des résultats.

Les véritables scripts Lua livrés sont exécutés dans le LuaJ de Cosmonautics. La plante utilise quaternion, forces aux quatre points, couples et inerties, dynamique rigide à 200 Hz, régime retardé à 20 Hz et propagation du graphe à un tick. La plante continue après un défaut : le repli ne fige pas le véhicule.

Critères : actif tout le long, erreur finale altitude < 0,3 m, vitesse finale < 0,2 m/s, erreur horizontale finale < 0,3 m et inclinaison maximale < 25°. Sur les dix dernières secondes : inclinaison RMS < 2° et vitesse RMS < 0,2 m/s. Une réussite ne borne pas les excursions transitoires : elles sont indiquées séparément.

| Scénario | Stress | Résultat | Erreur finale (m) | Inclinaison max (°) | RMS angle (°) | RMS vitesse (m/s) | T1 (s) | Défaut |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| level_hover | false | PASS | 0.007 | 0.00 | 0.000 | 0.027 | -1.00 | — |
| level_drop_2ms | false | PASS | 0.002 | 0.00 | 0.000 | 0.029 | -1.00 | — |
| level_drop_5ms | false | PASS | 0.000 | 0.00 | 0.000 | 0.029 | -1.00 | — |
| cold_rotors | false | PASS | 0.006 | 0.00 | 0.000 | 0.030 | -1.00 | — |
| tilt_pitch_5deg | false | PASS | 0.014 | 6.40 | 0.150 | 0.024 | -1.00 | — |
| tilt_roll_5deg | false | PASS | 0.018 | 4.97 | 0.173 | 0.028 | -1.00 | — |
| tilt_yaw_90deg | false | PASS | 0.000 | 4.99 | 0.080 | 0.016 | -1.00 | — |
| space_then_hold | false | PASS | 0.008 | 0.00 | 0.000 | 0.023 | -1.00 | — |
| forward_then_brake | false | PASS | 0.042 | 15.58 | 0.147 | 0.032 | 1.05 | — |
| diagonal_then_brake | false | FAIL | 0.106 | 16.78 | 3.011 | 0.805 | -1.00 | — |
| mass_loss_15percent | false | PASS | 0.001 | 0.00 | 0.000 | 0.026 | -1.00 | — |
| no_airframe_drag | false | PASS | 0.012 | 16.11 | 0.196 | 0.031 | 1.05 | — |
| radio_delay_2ticks | false | FAIL | 130.093 | 26.12 | 15.132 | 37.034 | 1.10 | FAULT: Near-level attitude envelope exceeded / pitch=-25.792763792138054 roll=0.0 MODULAIRE m=32.0 / RADIO_3: demande 12 reseau 13 |
| radio_delay_4ticks | false | FAIL | 130.496 | 30.78 | inf | inf | -1.00 | FAULT: Near-level attitude envelope exceeded / pitch=26.515754812617423 roll=0.0 MODULAIRE m=32.0 / RADIO_1: demande 12 reseau 13 |
| heavy_85kg | false | PASS | 0.003 | 0.00 | 0.000 | 0.015 | -1.00 | — |
| light_40kg | false | PASS | 0.004 | 0.00 | 0.000 | 0.030 | -1.00 | — |
| noise_position_2cm | false | PASS | 0.002 | 0.20 | 0.094 | 0.021 | -1.00 | — |
| gust_1ms | false | PASS | 0.004 | 7.01 | 0.152 | 0.025 | -1.00 | — |
| inertia_quarter | false | FAIL | 0.046 | 5.00 | 2.014 | 0.383 | -1.00 | — |
| inertia_fourfold | false | PASS | 0.009 | 4.99 | 0.025 | 0.013 | -1.00 | — |
| sustained_forward | false | PASS | 0.104 | 20.39 | 0.513 | 0.107 | 1.05 | — |
| reverse_every_second | false | FAIL | 0.374 | 22.20 | 1.748 | 0.445 | -1.00 | — |
| reverse_every_half_second | false | PASS | 0.010 | 7.14 | 0.117 | 0.021 | -1.00 | — |
| periodic_pitch_05hz | false | PASS | 0.005 | 3.43 | 0.158 | 0.031 | -1.00 | — |
| periodic_roll_1hz | false | PASS | 0.008 | 1.62 | 0.145 | 0.029 | -1.00 | — |
| attitude_noise_01deg | false | PASS | 0.003 | 4.99 | 0.102 | 0.016 | -1.00 | — |
| inertia_eighth | false | FAIL | 0.222 | 13.50 | 6.465 | 3.065 | -1.00 | — |
| inertia_quarter_delay2 | false | FAIL | 0.599 | 11.86 | 6.876 | 1.519 | -1.00 | — |
| held_forward_20s | false | FAIL | 8.807 | 26.85 | 2.461 | 10.467 | 1.05 | FAULT: Near-level attitude envelope exceeded / pitch=-26.207075239022096 roll=0.0 MODULAIRE m=32.0 |
| held_forward_no_drag | false | FAIL | 28.373 | 33.06 | 2.457 | 7.832 | 1.05 | FAULT: Near-level attitude envelope exceeded / pitch=-26.03538600938711 roll=0.0 MODULAIRE m=32.0 |
| held_forward_tilt15 | false | FAIL | 131.072 | 120.93 | inf | inf | 0.90 | FAULT: Near-level attitude envelope exceeded / pitch=-27.137714440691408 roll=0.0 MODULAIRE m=32.0 / RADIO_3: demande 14 reseau 15 |
| held_forward_heavy | true | PASS | 0.009 | 20.33 | 0.100 | 0.014 | 1.10 | — |
| held_forward_endurance | true | FAIL | 130.366 | 179.78 | inf | inf | 1.05 | FAULT: Insufficient lift at this mass/altitude/inflow / pitch=19.824614845433402 roll=0.0 MODULAIRE m=32.0 |
| travel_mass_loss | false | FAIL | 130.116 | 35.25 | inf | inf | 1.05 | FAULT: Near-level attitude envelope exceeded / pitch=-25.682946172328027 roll=0.0 MODULAIRE m=27.2 |
| course_left_arc | false | PASS | 0.005 | 20.59 | 0.072 | 0.015 | 1.05 | — |
| course_right_arc | false | PASS | 0.005 | 20.59 | 0.072 | 0.015 | 1.05 | — |
| course_no_drag | false | FAIL | 130.236 | 51.73 | inf | inf | 1.05 | FAULT: Near-level attitude envelope exceeded / pitch=27.928144272902642 roll=-8.088983600717828 MODULAIRE m=32.0 / RADIO_1: demande 13 reseau 14 |
| course_release_steer | false | PASS | 0.004 | 15.08 | 0.079 | 0.016 | 1.05 | — |
| course_turn_only | false | PASS | 0.008 | 13.48 | 0.074 | 0.017 | 1.05 | — |
| steer_at_rest | false | PASS | 0.009 | 0.00 | 0.000 | 0.024 | -1.00 | — |
| classic_strafe | false | PASS | 0.014 | 17.25 | 0.102 | 0.019 | -1.00 | — |
| course_straight_gust | false | FAIL | 24.987 | 29.73 | 2.140 | 7.295 | 1.05 | FAULT: Near-level attitude envelope exceeded / pitch=-25.814688125545015 roll=0.21768949794636616 MODULAIRE m=32.0 |
| course_reverse_arc | false | PASS | 0.005 | 20.59 | 0.072 | 0.015 | -1.00 | — |
| slow_spool | true | FAIL | 1.108 | 19.56 | 11.903 | 1.653 | -1.00 | — |
| com_offset_10cm | true | FAIL | 0.005 | 1.51 | 0.082 | 0.020 | -1.00 | — |
| com_offset_25cm | true | FAIL | 0.001 | 2.44 | 0.186 | 0.025 | -1.00 | — |
| rotor_weak_10percent | true | FAIL | 0.000 | 1.18 | 0.077 | 0.015 | -1.00 | — |
| swapped_front_rear | true | FAIL | 131.680 | 61.41 | 61.048 | 43.094 | -1.00 | FAULT: Near-level attitude envelope exceeded / pitch=27.246287552717178 roll=0.0 MODULAIRE m=32.0 |
| competing_tx_15 | true | FAIL | 131.286 | 173.12 | 165.122 | 42.578 | -1.00 | FAULT: Near-level attitude envelope exceeded / pitch=19.397988446417244 roll=26.05808628755726 MODULAIRE m=32.0 / RADIO_1: demande 13 reseau 15 |
| reversed_transmission | true | FAIL | 130.836 | 0.00 | 0.000 | 47.499 | -1.00 | — |

Paramètres de base : 32 kg, inerties diagonales supposées 250/400/230 kg·m², demi-largeur 3 m, demi-longueur 5 m, rotors à +1 m de Sputnik, altitude initiale Y=80, centre de masse centré, petits rotors identiques vers le haut, 256 RPM, gravité 11, retard radio 1 tick. Les amortissements 0,05 s⁻¹ sont hypothétiques ; un cas les supprime complètement.

Les signaux 0..15 sont des réductions : 0 = 256 RPM, 1 = 224 RPM et 15 = arrêt. Les traces CSV contiennent les signaux réellement appliqués par la plante et les quatre régimes.

RMS : moyenne quadratique sur les dix dernières secondes. T1 : délai depuis l’appui W pour atteindre 1 m/s vers l’avant ; −1 signifie non atteint pendant l’appui ou non applicable. L’erreur maximale transitoire reste disponible dans le CSV.

La masse et les dimensions sont des paramètres déclarés ; les inerties, le centre de masse et la mécanique ne sont pas mesurés. Le moteur physique Sable et le réseau cinétique Create ne sont pas lancés. Aucune certitude de vol en jeu ni qualification autopilote ne résulte de ce rapport.

Contrôleur SHA256 : `7e869a84b9c4a55524c37d9b028f944dab5e335376052a3b22376f5de05c5eee`.
Plante SHA256 : `54e5e5dfa4877a870c9827c15e86e87a1ed6da7d37d2e8427ab102112b3ef493`.
