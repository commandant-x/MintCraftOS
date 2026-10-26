# slow-radio / standard

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | FAIL | 0.195 | 0.286 | 3.070 | — | final_speed |
| cold-hover | PASS | 0.028 | 0.194 | 0.682 | — | — |
| climb | FAIL | 6.303 | 13.141 | 67.114 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_vertical_rate |
| descend | FAIL | 0.129 | 0.233 | 1.427 | — | transient_height |
| forward | FAIL | 0.808 | 6.124 | 36.031 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_height, braking |
| reverse | FAIL | 1.929 | 7.577 | 34.568 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_height, braking |
| left | FAIL | 5.750 | 13.812 | 65.537 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_height, braking |
| right | FAIL | 7.062 | 12.759 | 66.123 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_height, braking |
| forward-left | FAIL | 5.481 | 12.617 | 66.754 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| forward-right | FAIL | 4.692 | 12.692 | 66.041 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| reverse-left | FAIL | 5.086 | 12.891 | 66.911 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| reverse-right | FAIL | 4.604 | 13.645 | 67.561 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| turn-left | FAIL | 3.482 | 12.265 | 65.389 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_height, motion, braking |
| turn-right | FAIL | 7.057 | 12.452 | 65.147 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_height, motion, braking |
| climb-forward | FAIL | 3.087 | 5.559 | 35.027 | 6.000 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_vertical_rate |
| descend-left | FAIL | 2.754 | 13.233 | 65.258 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_vertical_rate, braking |
| vertical-cycle | FAIL | 4.636 | 12.914 | 65.859 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_vertical_rate |
| reverse-command | FAIL | 0.300 | 6.923 | 35.131 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_height, motion, braking |
| brake | FAIL | 0.808 | 6.124 | 36.031 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_height, braking |
| slalom | FAIL | 3.997 | 13.291 | 67.023 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_height, braking |
| gust | FAIL | 5.527 | 13.686 | 66.177 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt |
| load-swing | FAIL | 2.491 | 2.705 | 66.336 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt |
| recovery-diagonal | FAIL | 5.509 | 12.519 | 64.672 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, recovery |
| recovery-inverted | FAIL | 0.049 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/slow-radio-standard.pdf` et `traces/slow-radio/standard/`.
