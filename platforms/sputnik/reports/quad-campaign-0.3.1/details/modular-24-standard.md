# modular-24 / standard

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | FAIL | 2.313 | 5.904 | 0.000 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_speed_rms, final_speed, transient_height |
| cold-hover | FAIL | 2.594 | 5.950 | 0.000 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_speed_rms |
| climb | FAIL | 1.043 | 5.855 | 0.000 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_speed_rms, final_speed, transient_height, active_vertical_rate |
| descend | FAIL | 2.530 | 5.921 | 0.000 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_speed_rms, final_speed, transient_height |
| forward | FAIL | 0.715 | 0.796 | 24.135 | — | tail_height_peak, tail_height_rms, tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, braking |
| reverse | FAIL | 0.168 | 1.003 | 25.320 | — | tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, braking |
| left | FAIL | 0.342 | 1.587 | 22.536 | — | tail_height_peak, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| right | FAIL | 0.607 | 2.333 | 20.367 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| forward-left | FAIL | 0.002 | 0.870 | 24.727 | — | tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| forward-right | FAIL | 0.289 | 4.155 | 22.468 | 38.950 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| reverse-left | FAIL | 1.164 | 1.613 | 26.275 | — | tail_height_peak, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| reverse-right | FAIL | 0.210 | 0.960 | 23.793 | — | tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| turn-left | FAIL | 0.206 | 0.909 | 24.105 | — | tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, active_height, braking |
| turn-right | FAIL | 0.133 | 0.882 | 22.581 | — | tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, active_height, braking |
| climb-forward | FAIL | 0.532 | 0.653 | 21.359 | 7.450 | tail_height_rms, tail_tilt, tail_speed_rms, final_speed, transient_height, active_vertical_rate, motion, braking |
| descend-left | FAIL | 0.183 | 1.387 | 23.380 | 30.250 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, active_vertical_rate, braking |
| vertical-cycle | FAIL | 0.911 | 5.959 | 0.000 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_speed_rms, final_speed, transient_height, active_vertical_rate |
| reverse-command | FAIL | 0.473 | 1.014 | 24.373 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, active_height, motion, braking |
| brake | FAIL | 0.715 | 0.796 | 24.135 | — | tail_height_peak, tail_height_rms, tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, braking |
| slalom | FAIL | 2.132 | 3.846 | 26.597 | 4.250 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, active_height, motion |
| gust | FAIL | 0.333 | 1.622 | 19.452 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height |
| load-swing | FAIL | 2.156 | 8.571 | 35.368 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt |
| recovery-diagonal | FAIL | 0.435 | 1.013 | 23.773 | — | tail_height_span, tail_tilt, tail_speed_rms, final_speed, recovery |
| recovery-inverted | FAIL | 0.076 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/modular-24-standard.pdf` et `traces/modular-24/standard/`.
