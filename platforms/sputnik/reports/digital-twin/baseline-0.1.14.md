# Sputnik 0.1.14 — banc numérique 3D

**Simulation indépendante paramétrée ; pas un jumeau mesuré du véhicule du joueur.**

Cas de référence réussis : **12/20**. Les cas « stress » modifient volontairement les hypothèses du contrôleur ; ils ne sont pas exclus des résultats.

Les véritables scripts Lua livrés sont exécutés dans le LuaJ de Cosmonautics. La plante utilise quaternion, forces aux quatre points, couples et inerties, dynamique rigide à 200 Hz, régime retardé à 20 Hz et propagation du graphe à un tick. La plante continue après un défaut : le repli ne fige pas le véhicule.

Critères : actif tout le long, erreur finale altitude < 0,3 m, vitesse finale < 0,2 m/s, erreur horizontale finale < 0,3 m et inclinaison maximale < 25°. Une réussite ne borne pas les excursions transitoires : elles sont indiquées séparément.

| Scénario | Stress | Résultat | Erreur finale (m) | Erreur max (m) | Inclinaison max (°) | Défaut |
| --- | --- | --- | ---: | ---: | ---: | --- |
| level_hover | false | PASS | 0.003 | 0.014 | 0.00 | — |
| level_drop_2ms | false | PASS | 0.008 | 1.240 | 0.00 | — |
| level_drop_5ms | false | PASS | 0.024 | 3.208 | 0.00 | — |
| cold_rotors | false | PASS | 0.011 | 1.727 | 0.00 | — |
| tilt_pitch_5deg | false | PASS | 0.001 | 0.112 | 5.91 | — |
| tilt_roll_5deg | false | FAIL | 0.876 | 0.876 | 25.33 | FAULT: Near-level attitude envelope exceeded / pitch=1.8020472710909002E-16 roll=-25.33463406072938 m=32.0 |
| tilt_yaw_90deg | false | FAIL | 0.002 | 0.097 | 12.55 | — |
| space_then_hold | false | PASS | 0.009 | 1.097 | 0.00 | — |
| forward_then_brake | false | PASS | 0.004 | 0.166 | 12.54 | — |
| diagonal_then_brake | false | FAIL | 131.649 | 131.649 | 109.95 | FAULT: Near-level attitude envelope exceeded / pitch=5.190676751196115 roll=-25.910741177138384 m=32.0 / RADIO_1: demande 14 reseau 15 |
| mass_loss_15percent | false | PASS | 0.015 | 0.249 | 0.00 | — |
| no_airframe_drag | false | PASS | 0.003 | 0.178 | 12.62 | — |
| radio_delay_2ticks | false | FAIL | 0.017 | 0.237 | 14.91 | — |
| radio_delay_4ticks | false | FAIL | 0.027 | 0.201 | 21.55 | — |
| heavy_85kg | false | PASS | 0.002 | 0.041 | 0.00 | — |
| light_40kg | false | PASS | 0.002 | 0.005 | 0.00 | — |
| noise_position_2cm | false | PASS | 0.003 | 0.019 | 0.18 | — |
| gust_1ms | false | FAIL | 123.002 | 123.002 | 110.67 | FAULT: Near-level attitude envelope exceeded / pitch=3.4985883611575593E-16 roll=-25.53435518348408 m=32.0 |
| inertia_quarter | false | FAIL | 0.047 | 0.142 | 15.92 | — |
| inertia_fourfold | false | FAIL | 79.849 | 79.849 | 32.47 | FAULT: Near-level attitude envelope exceeded / pitch=-1.1072962553832626 roll=-25.21751386698393 m=32.0 |
| com_offset_10cm | true | FAIL | 0.062 | 0.062 | 16.61 | — |
| com_offset_25cm | true | FAIL | 4.559 | 4.559 | 27.57 | FAULT: Near-level attitude envelope exceeded / pitch=2.9328330447032587E-15 roll=25.164982510992786 m=32.0 |
| rotor_weak_10percent | true | FAIL | 0.002 | 0.220 | 3.96 | — |
| swapped_front_rear | true | FAIL | 130.308 | 130.308 | 179.68 | FAULT: Near-level attitude envelope exceeded / pitch=27.04688633709917 roll=0.0 m=32.0 / RADIO_1: demande 3 reseau 4 |
| competing_tx_15 | true | FAIL | 131.663 | 131.663 | 155.43 | FAULT: Near-level attitude envelope exceeded / pitch=26.11412955831613 roll=19.336009212895476 m=32.0 / RADIO_1: demande 0 reseau 15 |
| reversed_transmission | true | FAIL | 85.341 | 85.341 | 0.00 | — |

Paramètres de base : 32 kg, inerties diagonales supposées 250/400/230 kg·m², demi-largeur 3 m, demi-longueur 5 m, rotors à +1 m de Sputnik, altitude initiale Y=80, centre de masse centré, petits rotors identiques vers le haut, 256 RPM, gravité 11, retard radio 1 tick. Les amortissements 0,05 s⁻¹ sont hypothétiques ; un cas les supprime complètement.

Les signaux 0..15 sont des réductions : 0 = 256 RPM, 1 = 224 RPM et 15 = arrêt. Les traces CSV contiennent les signaux réellement appliqués par la plante et les quatre régimes.

La masse et les dimensions sont des paramètres déclarés ; les inerties, le centre de masse et la mécanique ne sont pas mesurés. Le moteur physique Sable et le réseau cinétique Create ne sont pas lancés. Aucune certitude de vol en jeu ni qualification autopilote ne résulte de ce rapport.

Contrôleur SHA256 : `cabc4e927d11e632643c3f1042975d79c76a3f5bdf91996a2f88d294de164781`.
Plante SHA256 : `8c4415c14ec6950ddd1f637f22664519ba1eb083b938dd87e396f93572e5b071`.
