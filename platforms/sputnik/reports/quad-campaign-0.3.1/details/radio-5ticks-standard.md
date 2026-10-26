# radio-5ticks / standard

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.325 | 0.902 | 2.949 | — | — |
| cold-hover | PASS | 0.253 | 0.836 | 3.245 | — | — |
| climb | FAIL | 0.123 | 0.420 | 1.823 | — | transient_height, active_vertical_rate |
| descend | FAIL | 0.048 | 0.285 | 1.215 | — | transient_height |
| forward | FAIL | 1.886 | 0.629 | 29.822 | — | tail_height_peak, tail_height_rms, tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, active_height, braking |
| reverse | FAIL | 1.609 | 1.063 | 30.893 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, active_height, braking |
| left | FAIL | 1.269 | 2.307 | 32.801 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_height, braking |
| right | FAIL | 1.657 | 0.959 | 30.099 | — | tail_height_peak, tail_height_rms, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_height, braking |
| forward-left | FAIL | 1.811 | 0.513 | 30.240 | — | tail_height_peak, tail_height_rms, tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, active_height, braking |
| forward-right | FAIL | 1.703 | 0.602 | 30.804 | — | tail_height_peak, tail_height_rms, tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, active_height, braking |
| reverse-left | FAIL | 1.364 | 0.723 | 30.309 | — | tail_height_peak, tail_height_rms, tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, active_height, braking |
| reverse-right | FAIL | 2.061 | 1.247 | 31.947 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, active_height, braking |
| turn-left | FAIL | 2.312 | 1.530 | 32.183 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, active_height, braking |
| turn-right | FAIL | 1.663 | 0.704 | 30.693 | — | tail_height_peak, tail_height_rms, tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, active_height, braking |
| climb-forward | FAIL | 1.754 | 1.277 | 28.731 | 4.400 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_vertical_rate |
| descend-left | FAIL | 1.472 | 0.656 | 31.469 | 12.150 | tail_height_peak, tail_height_rms, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_vertical_rate, braking |
| vertical-cycle | FAIL | 0.027 | 0.059 | 0.000 | — | transient_height, active_vertical_rate |
| reverse-command | FAIL | 1.572 | 0.575 | 30.153 | — | tail_height_peak, tail_height_rms, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_height, motion, braking |
| brake | FAIL | 1.886 | 0.629 | 29.822 | — | tail_height_peak, tail_height_rms, tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, active_height, braking |
| slalom | FAIL | 1.870 | 0.787 | 30.493 | — | tail_height_peak, tail_height_rms, tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, active_height, motion, braking |
| gust | FAIL | 1.579 | 1.093 | 30.921 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height |
| load-swing | FAIL | 5.092 | 1.836 | 34.734 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt |
| recovery-diagonal | FAIL | 1.777 | 0.450 | 30.252 | — | tail_height_peak, tail_height_rms, tail_tilt, tail_speed_rms, final_speed, recovery |
| recovery-inverted | FAIL | 0.190 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/radio-5ticks-standard.pdf` et `traces/radio-5ticks/standard/`.
