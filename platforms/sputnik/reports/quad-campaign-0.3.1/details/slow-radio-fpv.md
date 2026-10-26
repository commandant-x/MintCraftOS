# slow-radio / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.077 | 0.297 | 0.000 | — | — |
| cold-hover | FAIL | 0.336 | 1.048 | 4.934 | — | tail_height_span, tail_speed_rms |
| climb | FAIL | 0.182 | 0.934 | 4.869 | — | tail_speed_rms, final_speed, transient_height |
| descend | FAIL | 0.093 | 0.358 | 0.000 | — | transient_height |
| forward | FAIL | 0.250 | 1.086 | 3.775 | 10.600 | tail_height_span, tail_speed_rms, final_speed, transient_height, active_attitude, active_height, braking |
| reverse | FAIL | 0.127 | 1.052 | 5.108 | 13.700 | tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, active_height, braking |
| left | FAIL | 0.357 | 0.890 | 3.954 | 14.850 | transient_height, active_height, braking |
| right | FAIL | 0.066 | 0.989 | 2.516 | 15.700 | tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| forward-left | FAIL | 0.442 | 1.124 | 5.188 | 16.500 | tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| forward-right | FAIL | 0.080 | 0.467 | 1.223 | 10.600 | transient_height, active_height, braking |
| reverse-left | FAIL | 0.072 | 0.991 | 3.155 | 21.800 | tail_speed_rms, final_speed, transient_height, active_height, braking |
| reverse-right | FAIL | 0.088 | 0.481 | 1.748 | 9.800 | transient_height, active_height, braking |
| turn-left | FAIL | 0.051 | 0.745 | 2.678 | 7.050 | final_speed, active_attitude, active_height, braking |
| turn-right | FAIL | 0.361 | 0.597 | 3.859 | 6.850 | active_attitude, active_height, braking |
| climb-forward | FAIL | 0.045 | 0.550 | 1.204 | 15.200 | transient_height, transient_tilt, active_attitude, braking |
| descend-left | FAIL | 0.145 | 1.833 | 3.174 | 35.300 | tail_height_peak, tail_height_span, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_vertical_rate, braking |
| vertical-cycle | FAIL | 3.219 | 8.022 | 39.302 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude |
| reverse-command | FAIL | 0.353 | 0.643 | 4.217 | 12.350 | final_speed, transient_height, active_attitude, active_height, motion, braking |
| brake | FAIL | 0.250 | 1.086 | 3.775 | 10.600 | tail_height_span, tail_speed_rms, final_speed, transient_height, active_attitude, active_height, braking |
| slalom | FAIL | 0.139 | 0.831 | 3.082 | 7.150 | tail_speed_rms, final_speed, active_attitude, active_height, motion, braking |
| gust | FAIL | 0.530 | 1.114 | 5.761 | — | tail_height_span, tail_tilt, tail_speed_rms |
| load-swing | FAIL | 0.928 | 4.874 | 12.082 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed |
| recovery-diagonal | PASS | 0.188 | 0.416 | 2.614 | — | — |
| recovery-inverted | FAIL | 80.667 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/slow-radio-fpv.pdf` et `traces/slow-radio/fpv/`.
