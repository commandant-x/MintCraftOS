# radio-5ticks / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.049 | 0.052 | 0.673 | — | — |
| cold-hover | PASS | 0.171 | 0.293 | 1.737 | — | — |
| climb | FAIL | 0.211 | 0.397 | 28.216 | — | tail_tilt, tail_speed_rms, final_speed, transient_height |
| descend | PASS | 0.101 | 0.275 | 1.104 | — | — |
| forward | FAIL | 0.145 | 0.501 | 25.844 | — | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| reverse | FAIL | 0.074 | 0.448 | 26.651 | 6.450 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| left | FAIL | 0.161 | 0.623 | 27.683 | — | tail_tilt, tail_speed_rms, final_speed, active_attitude, active_height, braking |
| right | FAIL | 0.715 | 0.655 | 29.254 | — | tail_height_peak, tail_height_rms, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| forward-left | FAIL | 0.136 | 0.498 | 28.031 | — | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| forward-right | FAIL | 0.225 | 0.364 | 24.662 | — | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| reverse-left | FAIL | 0.046 | 0.525 | 29.639 | — | tail_tilt, tail_speed_rms, final_speed, active_height, braking |
| reverse-right | FAIL | 0.068 | 0.263 | 25.941 | — | tail_tilt, tail_speed_rms, final_speed, active_height, braking |
| turn-left | FAIL | 0.011 | 0.268 | 26.908 | — | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| turn-right | FAIL | 0.223 | 0.600 | 29.328 | — | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| climb-forward | FAIL | 0.142 | 0.531 | 26.641 | — | tail_tilt, tail_speed_rms, final_speed, transient_height, braking |
| descend-left | FAIL | 0.247 | 0.612 | 26.097 | — | tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, active_vertical_rate, motion, braking |
| vertical-cycle | FAIL | 37.583 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_vertical_rate |
| reverse-command | FAIL | 0.098 | 0.329 | 28.749 | — | tail_tilt, tail_speed_rms, final_speed, transient_tilt, active_attitude, active_height, braking |
| brake | FAIL | 0.145 | 0.501 | 25.844 | — | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| slalom | FAIL | 0.086 | 0.643 | 25.028 | — | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_height, motion, braking |
| gust | FAIL | 0.029 | 0.627 | 28.455 | — | tail_tilt, tail_speed_rms, final_speed |
| load-swing | FAIL | 0.334 | 1.599 | 35.596 | — | tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_tilt |
| recovery-diagonal | FAIL | 0.002 | 0.675 | 25.994 | — | tail_tilt, tail_speed_rms, final_speed, recovery |
| recovery-inverted | FAIL | 51.203 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/radio-5ticks-fpv.pdf` et `traces/radio-5ticks/fpv/`.
