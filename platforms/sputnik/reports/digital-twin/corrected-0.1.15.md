# Sputnik 0.1.15 — banc numérique 3D

**Simulation indépendante paramétrée ; pas un jumeau mesuré du véhicule du joueur.**

Cas de référence réussis : **19/20**. Les cas « stress » modifient volontairement les hypothèses du contrôleur ; ils ne sont pas exclus des résultats.

Les véritables scripts Lua livrés sont exécutés dans le LuaJ de Cosmonautics. La plante utilise quaternion, forces aux quatre points, couples et inerties, dynamique rigide à 200 Hz, régime retardé à 20 Hz et propagation du graphe à un tick. La plante continue après un défaut : le repli ne fige pas le véhicule.

Critères : actif tout le long, erreur finale altitude < 0,3 m, vitesse finale < 0,2 m/s, erreur horizontale finale < 0,3 m et inclinaison maximale < 25°. Une réussite ne borne pas les excursions transitoires : elles sont indiquées séparément.

| Scénario | Stress | Résultat | Erreur finale (m) | Erreur max (m) | Inclinaison max (°) | Défaut |
| --- | --- | --- | ---: | ---: | ---: | --- |
| level_hover | false | PASS | 0.003 | 0.014 | 0.00 | — |
| level_drop_2ms | false | PASS | 0.008 | 1.240 | 0.00 | — |
| level_drop_5ms | false | PASS | 0.024 | 3.208 | 0.00 | — |
| cold_rotors | false | PASS | 0.011 | 1.727 | 0.00 | — |
| tilt_pitch_5deg | false | PASS | 0.000 | 0.045 | 5.00 | — |
| tilt_roll_5deg | false | PASS | 0.001 | 0.042 | 5.00 | — |
| tilt_yaw_90deg | false | PASS | 0.000 | 0.052 | 5.00 | — |
| space_then_hold | false | PASS | 0.009 | 1.097 | 0.00 | — |
| forward_then_brake | false | PASS | 0.001 | 0.075 | 6.78 | — |
| diagonal_then_brake | false | PASS | 0.003 | 0.044 | 6.41 | — |
| mass_loss_15percent | false | PASS | 0.015 | 0.249 | 0.00 | — |
| no_airframe_drag | false | PASS | 0.001 | 0.081 | 7.44 | — |
| radio_delay_2ticks | false | PASS | 0.003 | 0.088 | 7.46 | — |
| radio_delay_4ticks | false | PASS | 0.001 | 0.116 | 5.00 | — |
| heavy_85kg | false | PASS | 0.002 | 0.041 | 0.00 | — |
| light_40kg | false | PASS | 0.002 | 0.005 | 0.00 | — |
| noise_position_2cm | false | PASS | 0.000 | 0.019 | 0.05 | — |
| gust_1ms | false | PASS | 0.000 | 0.019 | 3.24 | — |
| inertia_quarter | false | FAIL | 0.012 | 0.058 | 12.49 | — |
| inertia_fourfold | false | PASS | 0.001 | 0.063 | 5.00 | — |
| com_offset_10cm | true | FAIL | 0.002 | 0.037 | 3.30 | — |
| com_offset_25cm | true | FAIL | 0.001 | 0.101 | 8.17 | — |
| rotor_weak_10percent | true | FAIL | 0.008 | 0.218 | 4.87 | — |
| swapped_front_rear | true | FAIL | 132.005 | 132.005 | 179.75 | FAULT: Near-level attitude envelope exceeded / pitch=25.35870708340993 roll=0.0 m=32.0 / RADIO_1: demande 6 reseau 7 |
| competing_tx_15 | true | FAIL | 130.426 | 130.426 | 155.83 | FAULT: Near-level attitude envelope exceeded / pitch=26.663596834593246 roll=19.915576204178638 m=32.0 / RADIO_1: demande 0 reseau 15 |
| reversed_transmission | true | FAIL | 85.341 | 85.341 | 0.00 | — |

Paramètres de base : 32 kg, inerties diagonales supposées 250/400/230 kg·m², demi-largeur 3 m, demi-longueur 5 m, rotors à +1 m de Sputnik, altitude initiale Y=80, centre de masse centré, petits rotors identiques vers le haut, 256 RPM, gravité 11, retard radio 1 tick. Les amortissements 0,05 s⁻¹ sont hypothétiques ; un cas les supprime complètement.

Les signaux 0..15 sont des réductions : 0 = 256 RPM, 1 = 224 RPM et 15 = arrêt. Les traces CSV contiennent les signaux réellement appliqués par la plante et les quatre régimes.

La masse et les dimensions sont des paramètres déclarés ; les inerties, le centre de masse et la mécanique ne sont pas mesurés. Le moteur physique Sable et le réseau cinétique Create ne sont pas lancés. Aucune certitude de vol en jeu ni qualification autopilote ne résulte de ce rapport.

Contrôleur SHA256 : `9cfaff8c430b61bc91523c03536c74edd04a0a0c1ce3d49a0f9863c23414ffb4`.
Plante SHA256 : `8c4415c14ec6950ddd1f637f22664519ba1eb083b938dd87e396f93572e5b071`.
