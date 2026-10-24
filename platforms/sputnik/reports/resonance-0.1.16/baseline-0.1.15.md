# Sputnik 0.1.15 — banc numérique 3D

**Simulation indépendante paramétrée ; pas un jumeau mesuré du véhicule du joueur.**

Cas de référence réussis : **25/28**. Les cas « stress » modifient volontairement les hypothèses du contrôleur ; ils ne sont pas exclus des résultats.

Les véritables scripts Lua livrés sont exécutés dans le LuaJ de Cosmonautics. La plante utilise quaternion, forces aux quatre points, couples et inerties, dynamique rigide à 200 Hz, régime retardé à 20 Hz et propagation du graphe à un tick. La plante continue après un défaut : le repli ne fige pas le véhicule.

Critères : actif tout le long, erreur finale altitude < 0,3 m, vitesse finale < 0,2 m/s, erreur horizontale finale < 0,3 m et inclinaison maximale < 25°. Sur les dix dernières secondes : inclinaison RMS < 2° et vitesse RMS < 0,2 m/s. Une réussite ne borne pas les excursions transitoires : elles sont indiquées séparément.

| Scénario | Stress | Résultat | Erreur finale (m) | Inclinaison max (°) | RMS angle (°) | RMS vitesse (m/s) | T50 (s) | Défaut |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| level_hover | false | PASS | 0.003 | 0.00 | 0.000 | 0.007 | -1.00 | — |
| level_drop_2ms | false | PASS | 0.008 | 0.00 | 0.000 | 0.007 | -1.00 | — |
| level_drop_5ms | false | PASS | 0.024 | 0.00 | 0.000 | 0.009 | -1.00 | — |
| cold_rotors | false | PASS | 0.011 | 0.00 | 0.000 | 0.008 | -1.00 | — |
| tilt_pitch_5deg | false | PASS | 0.000 | 5.00 | 0.185 | 0.039 | -1.00 | — |
| tilt_roll_5deg | false | PASS | 0.001 | 5.00 | 0.039 | 0.011 | -1.00 | — |
| tilt_yaw_90deg | false | PASS | 0.000 | 5.00 | 0.179 | 0.038 | -1.00 | — |
| space_then_hold | false | PASS | 0.009 | 0.00 | 0.000 | 0.014 | -1.00 | — |
| forward_then_brake | false | PASS | 0.001 | 6.78 | 0.196 | 0.042 | -1.00 | — |
| diagonal_then_brake | false | PASS | 0.003 | 6.41 | 0.148 | 0.032 | -1.00 | — |
| mass_loss_15percent | false | PASS | 0.015 | 0.00 | 0.000 | 0.029 | -1.00 | — |
| no_airframe_drag | false | PASS | 0.001 | 7.44 | 0.348 | 0.081 | -1.00 | — |
| radio_delay_2ticks | false | PASS | 0.003 | 7.46 | 0.227 | 0.052 | -1.00 | — |
| radio_delay_4ticks | false | PASS | 0.001 | 5.00 | 0.051 | 0.016 | -1.00 | — |
| heavy_85kg | false | PASS | 0.002 | 0.00 | 0.000 | 0.007 | -1.00 | — |
| light_40kg | false | PASS | 0.002 | 0.00 | 0.000 | 0.005 | -1.00 | — |
| noise_position_2cm | false | PASS | 0.000 | 0.05 | 0.021 | 0.007 | -1.00 | — |
| gust_1ms | false | PASS | 0.000 | 3.24 | 0.016 | 0.006 | -1.00 | — |
| inertia_quarter | false | FAIL | 0.012 | 12.49 | 8.381 | 2.700 | -1.00 | — |
| inertia_fourfold | false | PASS | 0.001 | 5.00 | 0.010 | 0.005 | -1.00 | — |
| sustained_forward | false | PASS | 0.000 | 5.79 | 0.261 | 0.071 | 2.10 | — |
| reverse_every_second | false | PASS | 0.002 | 3.42 | 0.127 | 0.040 | -1.00 | — |
| reverse_every_half_second | false | PASS | 0.001 | 1.28 | 0.044 | 0.015 | -1.00 | — |
| periodic_pitch_05hz | false | PASS | 0.002 | 3.80 | 0.166 | 0.053 | -1.00 | — |
| periodic_roll_1hz | false | PASS | 0.000 | 1.92 | 0.030 | 0.010 | -1.00 | — |
| attitude_noise_01deg | false | PASS | 0.002 | 5.00 | 0.080 | 0.017 | -1.00 | — |
| inertia_eighth | false | FAIL | 0.069 | 15.97 | 10.446 | 3.971 | -1.00 | — |
| inertia_quarter_delay2 | false | FAIL | 0.025 | 13.93 | 8.729 | 3.000 | -1.00 | — |
| slow_spool | true | PASS | 0.008 | 5.00 | 0.321 | 0.100 | -1.00 | — |
| com_offset_10cm | true | FAIL | 0.002 | 3.30 | 0.035 | 0.008 | -1.00 | — |
| com_offset_25cm | true | FAIL | 0.001 | 8.17 | 0.768 | 3.040 | -1.00 | — |
| rotor_weak_10percent | true | FAIL | 0.008 | 4.87 | 0.177 | 0.053 | -1.00 | — |
| swapped_front_rear | true | FAIL | 132.005 | 179.75 | 134.642 | 27.289 | -1.00 | FAULT: Near-level attitude envelope exceeded / pitch=25.35870708340993 roll=0.0 m=32.0 / RADIO_1: demande 6 reseau 7 |
| competing_tx_15 | true | FAIL | 130.426 | 155.83 | 93.562 | 39.055 | -1.00 | FAULT: Near-level attitude envelope exceeded / pitch=26.663596834593246 roll=19.915576204178638 m=32.0 / RADIO_1: demande 0 reseau 15 |
| reversed_transmission | true | FAIL | 85.341 | 0.00 | 0.000 | 7.161 | -1.00 | — |

Paramètres de base : 32 kg, inerties diagonales supposées 250/400/230 kg·m², demi-largeur 3 m, demi-longueur 5 m, rotors à +1 m de Sputnik, altitude initiale Y=80, centre de masse centré, petits rotors identiques vers le haut, 256 RPM, gravité 11, retard radio 1 tick. Les amortissements 0,05 s⁻¹ sont hypothétiques ; un cas les supprime complètement.

Les signaux 0..15 sont des réductions : 0 = 256 RPM, 1 = 224 RPM et 15 = arrêt. Les traces CSV contiennent les signaux réellement appliqués par la plante et les quatre régimes.

RMS : moyenne quadratique sur les dix dernières secondes. T50 : délai depuis l’appui W pour atteindre 1 m/s vers l’avant (50 % de la consigne de 2 m/s) ; −1 signifie non atteint pendant l’appui ou non applicable. L’erreur maximale transitoire reste disponible dans le CSV.

La masse et les dimensions sont des paramètres déclarés ; les inerties, le centre de masse et la mécanique ne sont pas mesurés. Le moteur physique Sable et le réseau cinétique Create ne sont pas lancés. Aucune certitude de vol en jeu ni qualification autopilote ne résulte de ce rapport.

Contrôleur SHA256 : `9cfaff8c430b61bc91523c03536c74edd04a0a0c1ce3d49a0f9863c23414ffb4`.
Plante SHA256 : `2b0bc26de6b7c0692de1f716074875a963d78e30f558e0706f9aaca37ca1d522`.
