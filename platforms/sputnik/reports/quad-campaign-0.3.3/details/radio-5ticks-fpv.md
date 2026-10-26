# radio-5ticks / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.013 | 0.025 | 0.579 | — | — |
| cold-hover | PASS | 0.019 | 0.044 | 0.510 | — | — |
| climb | FAIL | 0.038 | 0.085 | 15.117 | — | tail_tilt, tail_speed_rms, final_speed, transient_height |
| descend | PASS | 0.012 | 0.052 | 0.430 | — | — |
| forward | FAIL | 0.001 | 0.669 | 14.059 | — | tail_tilt, tail_speed_rms, final_speed, braking |
| reverse | FAIL | 0.026 | 0.706 | 13.275 | — | tail_tilt, tail_speed_rms, final_speed, braking |
| left | FAIL | 0.051 | 0.229 | 14.089 | 8.050 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, braking |
| right | FAIL | 0.306 | 0.514 | 18.530 | 7.700 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, braking |
| forward-left | FAIL | 0.072 | 0.113 | 14.924 | — | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, braking |
| forward-right | FAIL | 0.018 | 0.113 | 14.118 | 9.350 | tail_tilt, tail_speed_rms, final_speed, transient_height, braking |
| reverse-left | FAIL | 0.001 | 0.097 | 13.808 | — | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, braking |
| reverse-right | FAIL | 0.025 | 0.121 | 14.751 | — | tail_tilt, tail_speed_rms, final_speed, transient_height, braking |
| turn-left | FAIL | 0.038 | 0.100 | 14.534 | — | tail_tilt, tail_speed_rms, final_speed, braking |
| turn-right | FAIL | 0.038 | 0.310 | 15.122 | — | tail_tilt, tail_speed_rms, final_speed, braking |
| climb-forward | FAIL | 0.065 | 0.137 | 15.232 | 6.050 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, braking |
| descend-left | FAIL | 0.009 | 0.359 | 12.592 | — | tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, braking |
| vertical-cycle | FAIL | 0.110 | 0.188 | 14.761 | — | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_vertical_rate |
| reverse-command | FAIL | 0.031 | 0.386 | 12.916 | — | tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, active_height, braking |
| brake | FAIL | 0.001 | 0.669 | 14.059 | — | tail_tilt, tail_speed_rms, final_speed, braking |
| slalom | FAIL | 0.082 | 0.088 | 14.122 | — | tail_tilt, tail_speed_rms, final_speed, active_attitude, motion, braking |
| gust | FAIL | 0.265 | 0.501 | 13.292 | — | tail_tilt, tail_speed_rms, final_speed |
| load-swing | FAIL | 1.274 | 3.472 | 24.534 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed |
| recovery-diagonal | FAIL | 0.047 | 0.138 | 13.980 | — | tail_tilt, tail_speed_rms, final_speed, recovery |
| recovery-inverted | FAIL | 51.203 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/radio-5ticks-fpv.pdf` et `traces/radio-5ticks/fpv/`.
