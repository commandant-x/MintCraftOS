# slow-radio / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.014 | 0.160 | 0.000 | — | — |
| cold-hover | FAIL | 0.718 | 3.331 | 30.673 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_tilt |
| climb | FAIL | 2.286 | 3.325 | 39.117 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt |
| descend | FAIL | 0.073 | 0.202 | 0.000 | — | transient_height |
| forward | FAIL | 0.781 | 6.007 | 22.611 | 22.600 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| reverse | FAIL | 2.061 | 3.721 | 30.619 | 25.650 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| left | FAIL | 26.722 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| right | FAIL | 33.520 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| forward-left | FAIL | 1.052 | 4.792 | 29.342 | 28.650 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| forward-right | FAIL | 0.340 | 3.979 | 37.869 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| reverse-left | FAIL | 1.095 | 1.953 | 34.214 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| reverse-right | FAIL | 0.760 | 2.311 | 17.516 | 41.200 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| turn-left | FAIL | 0.972 | 1.816 | 29.161 | 33.900 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| turn-right | FAIL | 0.134 | 3.948 | 22.324 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| climb-forward | FAIL | 0.095 | 3.411 | 25.374 | 15.200 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, braking |
| descend-left | FAIL | 0.524 | 5.468 | 39.932 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, braking |
| vertical-cycle | FAIL | 19.470 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_vertical_rate |
| reverse-command | FAIL | 0.320 | 2.825 | 21.326 | 23.250 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, active_height, motion, braking |
| brake | FAIL | 0.781 | 6.007 | 22.611 | 22.600 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| slalom | FAIL | 0.034 | 1.709 | 23.329 | 20.300 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, active_height, motion, braking |
| gust | FAIL | 2.250 | 3.038 | 34.542 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt |
| load-swing | FAIL | 0.865 | 2.331 | 28.380 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed |
| recovery-diagonal | FAIL | 0.922 | 2.366 | 15.174 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, recovery |
| recovery-inverted | FAIL | 80.039 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/slow-radio-fpv.pdf` et `traces/slow-radio/fpv/`.
