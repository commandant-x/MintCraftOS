# very-low-inertia / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.001 | 0.014 | 0.000 | — | — |
| cold-hover | PASS | 0.006 | 0.018 | 0.000 | — | — |
| climb | FAIL | 0.007 | 0.023 | 0.000 | — | transient_height |
| descend | PASS | 0.010 | 0.043 | 0.000 | — | — |
| forward | FAIL | 0.001 | 0.021 | 0.017 | 7.250 | braking |
| reverse | FAIL | 0.001 | 0.021 | 0.017 | 7.250 | braking |
| left | FAIL | 0.002 | 0.017 | 10.989 | — | tail_tilt, tail_speed_rms, final_speed, transient_tilt, active_attitude, braking |
| right | FAIL | 0.002 | 0.017 | 10.989 | — | tail_tilt, tail_speed_rms, final_speed, transient_tilt, active_attitude, braking |
| forward-left | FAIL | 0.001 | 0.009 | 2.085 | — | tail_speed_rms, final_speed, active_attitude, braking |
| forward-right | FAIL | 0.001 | 0.009 | 2.085 | — | tail_speed_rms, final_speed, active_attitude, braking |
| reverse-left | FAIL | 0.001 | 0.009 | 2.085 | — | tail_speed_rms, final_speed, active_attitude, braking |
| reverse-right | FAIL | 0.001 | 0.009 | 2.085 | — | tail_speed_rms, final_speed, active_attitude, braking |
| turn-left | FAIL | 0.003 | 0.007 | 2.091 | — | tail_speed_rms, final_speed, active_attitude, motion, braking |
| turn-right | FAIL | 0.003 | 0.007 | 2.091 | — | tail_speed_rms, final_speed, active_attitude, motion, braking |
| climb-forward | FAIL | 0.007 | 0.011 | 0.017 | 5.700 | transient_height, active_attitude |
| descend-left | FAIL | 0.009 | 0.010 | 6.169 | — | tail_tilt, tail_speed_rms, final_speed, transient_tilt, active_attitude, braking |
| vertical-cycle | FAIL | 0.005 | 0.016 | 0.000 | — | transient_height |
| reverse-command | FAIL | 0.007 | 0.016 | 4.591 | — | tail_speed_rms, final_speed, transient_tilt, active_attitude, active_height, braking |
| brake | FAIL | 0.001 | 0.021 | 0.017 | 7.250 | braking |
| slalom | FAIL | 0.001 | 0.016 | 0.013 | 8.200 | active_attitude, motion, braking |
| gust | FAIL | 0.002 | 0.006 | 1.403 | — | tail_speed_rms, final_speed |
| load-swing | PASS | 0.034 | 0.111 | 0.005 | — | — |
| recovery-diagonal | FAIL | 0.001 | 0.007 | 3.408 | — | tail_speed_rms, final_speed, recovery |
| recovery-inverted | FAIL | 81.589 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/very-low-inertia-fpv.pdf` et `traces/very-low-inertia/fpv/`.
