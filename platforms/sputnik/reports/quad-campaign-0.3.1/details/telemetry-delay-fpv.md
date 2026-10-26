# telemetry-delay / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.008 | 0.026 | 0.000 | — | — |
| cold-hover | PASS | 0.005 | 0.020 | 0.000 | — | — |
| climb | FAIL | 0.137 | 0.226 | 0.810 | — | transient_height |
| descend | FAIL | 0.008 | 0.061 | 0.000 | — | transient_height |
| forward | FAIL | 0.973 | 9.996 | 23.355 | 6.650 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| reverse | FAIL | 6.036 | 9.863 | 13.180 | 7.850 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, transient_height, active_height, braking |
| left | FAIL | 0.651 | 8.685 | 16.680 | 6.050 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, braking |
| right | FAIL | 0.006 | 0.310 | 0.576 | 7.200 | transient_height, transient_tilt, braking |
| forward-left | FAIL | 0.652 | 1.602 | 0.953 | 7.150 | tail_height_peak, tail_height_rms, tail_height_span, transient_height, transient_tilt, braking |
| forward-right | FAIL | 1.421 | 5.411 | 18.192 | 6.950 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, braking |
| reverse-left | FAIL | 0.183 | 0.400 | 0.597 | 7.100 | transient_height, braking |
| reverse-right | FAIL | 0.234 | 0.333 | 0.718 | 7.100 | transient_height, braking |
| turn-left | FAIL | 2.977 | 16.437 | 30.313 | 7.600 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, active_height, braking |
| turn-right | FAIL | 7.857 | 10.267 | 16.260 | 19.550 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, active_height, braking |
| climb-forward | FAIL | 10.625 | 15.557 | 29.528 | 7.550 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, braking |
| descend-left | FAIL | 0.377 | 2.470 | 20.144 | 4.850 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, transient_height |
| vertical-cycle | FAIL | 0.532 | 2.417 | 10.109 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, transient_height, active_attitude, active_vertical_rate |
| reverse-command | FAIL | 1.989 | 7.968 | 20.777 | 2.200 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_height |
| brake | FAIL | 0.973 | 9.996 | 23.355 | 6.650 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| slalom | FAIL | 2.068 | 4.381 | 14.007 | 11.700 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, active_height, motion, braking |
| gust | PASS | 0.070 | 0.276 | 1.126 | — | — |
| load-swing | FAIL | 235.066 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height |
| recovery-diagonal | FAIL | 2.049 | 6.892 | 23.230 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, recovery |
| recovery-inverted | FAIL | 1.163 | 5.392 | 8.857 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/telemetry-delay-fpv.pdf` et `traces/telemetry-delay/fpv/`.
