# slow-radio / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.119 | 0.470 | 0.000 | — | — |
| cold-hover | FAIL | 0.225 | 0.951 | 9.876 | — | tail_tilt, tail_speed_rms, final_speed |
| climb | FAIL | 0.024 | 0.043 | 0.000 | — | transient_height |
| descend | FAIL | 0.198 | 0.528 | 0.000 | — | transient_height |
| forward | FAIL | 0.289 | 0.887 | 11.792 | 13.250 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, braking |
| reverse | FAIL | 0.099 | 0.676 | 9.436 | 10.500 | tail_tilt, tail_speed_rms, transient_height, transient_tilt, active_height, braking |
| left | FAIL | 0.100 | 0.675 | 13.547 | 8.300 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| right | FAIL | 0.102 | 0.873 | 12.976 | 12.950 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| forward-left | FAIL | 0.093 | 0.311 | 13.783 | — | tail_tilt, tail_speed_rms, transient_height, transient_tilt, active_height, braking |
| forward-right | FAIL | 0.210 | 0.541 | 13.771 | 17.450 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| reverse-left | FAIL | 0.026 | 0.510 | 13.367 | 22.350 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| reverse-right | FAIL | 0.026 | 0.334 | 4.888 | 20.150 | tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| turn-left | FAIL | 0.133 | 0.440 | 8.154 | 15.600 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, braking |
| turn-right | FAIL | 0.124 | 0.414 | 12.700 | 21.900 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, braking |
| climb-forward | FAIL | 0.173 | 0.441 | 10.259 | 15.400 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, braking |
| descend-left | FAIL | 0.036 | 0.461 | 9.199 | 16.750 | tail_tilt, tail_speed_rms, final_speed, transient_height, braking |
| vertical-cycle | FAIL | 0.003 | 0.291 | 0.000 | — | transient_height |
| reverse-command | FAIL | 0.074 | 0.399 | 9.391 | 16.550 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_height, motion, braking |
| brake | FAIL | 0.289 | 0.887 | 11.792 | 13.250 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, braking |
| slalom | FAIL | 0.103 | 0.708 | 14.065 | 14.300 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, braking |
| gust | FAIL | 0.115 | 0.362 | 14.141 | — | tail_tilt, tail_speed_rms, final_speed |
| load-swing | FAIL | 0.674 | 2.810 | 17.323 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed |
| recovery-diagonal | FAIL | 0.097 | 0.500 | 10.254 | — | tail_tilt, tail_speed_rms, final_speed, recovery |
| recovery-inverted | FAIL | 80.415 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/slow-radio-fpv.pdf` et `traces/slow-radio/fpv/`.
