# slow-radio / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.068 | 0.151 | 0.000 | — | — |
| cold-hover | FAIL | 0.036 | 0.307 | 14.053 | — | tail_tilt, tail_speed_rms, final_speed |
| climb | FAIL | 0.199 | 0.374 | 5.948 | — | tail_tilt, tail_speed_rms, final_speed, transient_height |
| descend | FAIL | 0.049 | 0.331 | 9.559 | — | tail_tilt, tail_speed_rms, final_speed, transient_height |
| forward | FAIL | 0.114 | 0.353 | 9.687 | 9.050 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| reverse | FAIL | 0.054 | 0.333 | 9.356 | 7.200 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| left | FAIL | 0.072 | 0.564 | 14.370 | 20.050 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| right | FAIL | 0.078 | 0.393 | 13.942 | 12.150 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| forward-left | FAIL | 0.042 | 0.341 | 9.192 | 21.650 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| forward-right | FAIL | 0.004 | 0.316 | 9.698 | 20.800 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| reverse-left | FAIL | 0.018 | 0.287 | 9.370 | 21.300 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| reverse-right | FAIL | 0.001 | 0.390 | 13.682 | 25.950 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| turn-left | FAIL | 0.117 | 0.527 | 6.348 | 17.650 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_height, braking |
| turn-right | FAIL | 0.011 | 0.327 | 8.939 | 14.900 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_height, braking |
| climb-forward | FAIL | 0.117 | 0.353 | 9.742 | 16.650 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, braking |
| descend-left | FAIL | 0.410 | 0.539 | 14.112 | 9.900 | tail_tilt, tail_speed_rms, final_speed, transient_height, braking |
| vertical-cycle | FAIL | 0.030 | 0.317 | 4.488 | — | final_speed, transient_height, active_attitude |
| reverse-command | FAIL | 0.125 | 0.445 | 9.346 | 14.800 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_height, motion, braking |
| brake | FAIL | 0.114 | 0.353 | 9.687 | 9.050 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| slalom | FAIL | 0.003 | 0.312 | 9.388 | 12.550 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, motion, braking |
| gust | FAIL | 0.082 | 0.246 | 8.888 | — | tail_tilt, tail_speed_rms, final_speed |
| load-swing | FAIL | 1.131 | 2.566 | 15.029 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed |
| recovery-diagonal | FAIL | 0.140 | 0.377 | 9.969 | — | tail_tilt, tail_speed_rms, final_speed, recovery |
| recovery-inverted | FAIL | 80.661 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/slow-radio-fpv.pdf` et `traces/slow-radio/fpv/`.
