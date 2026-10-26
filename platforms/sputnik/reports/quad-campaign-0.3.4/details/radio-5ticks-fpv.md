# radio-5ticks / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.049 | 0.052 | 0.673 | — | — |
| cold-hover | PASS | 0.066 | 0.202 | 0.942 | — | — |
| climb | FAIL | 0.673 | 1.552 | 29.302 | — | tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt |
| descend | PASS | 0.101 | 0.275 | 1.104 | — | — |
| forward | FAIL | 0.044 | 1.072 | 26.625 | — | tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| reverse | FAIL | 0.380 | 2.558 | 35.716 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| left | FAIL | 0.170 | 1.424 | 33.930 | — | tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_height, braking |
| right | FAIL | 0.092 | 0.773 | 27.407 | — | tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| forward-left | FAIL | 0.818 | 1.663 | 29.549 | — | tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| forward-right | FAIL | 0.478 | 1.292 | 29.712 | — | tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| reverse-left | FAIL | 0.746 | 1.692 | 28.916 | — | tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| reverse-right | FAIL | 0.056 | 2.083 | 30.996 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| turn-left | FAIL | 0.534 | 1.175 | 28.461 | — | tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| turn-right | FAIL | 0.612 | 2.428 | 31.258 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, transient_height, active_height, braking |
| climb-forward | FAIL | 0.130 | 2.047 | 32.014 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, braking |
| descend-left | FAIL | 0.084 | 1.864 | 30.338 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, motion, braking |
| vertical-cycle | FAIL | 58.857 | 1.249 | 19.837 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_vertical_rate |
| reverse-command | FAIL | 0.144 | 1.146 | 27.144 | — | tail_height_span, tail_tilt, tail_speed_rms, final_speed, active_attitude, active_height, braking |
| brake | FAIL | 0.044 | 1.072 | 26.625 | — | tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| slalom | FAIL | 0.106 | 0.871 | 31.310 | — | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_height, motion, braking |
| gust | FAIL | 0.331 | 1.998 | 27.460 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed |
| load-swing | FAIL | 0.501 | 2.237 | 37.376 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_tilt |
| recovery-diagonal | FAIL | 0.863 | 1.841 | 28.018 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, recovery |
| recovery-inverted | FAIL | 51.203 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/radio-5ticks-fpv.pdf` et `traces/radio-5ticks/fpv/`.
