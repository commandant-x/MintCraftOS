# slow-radio / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.014 | 0.160 | 0.000 | — | — |
| cold-hover | PASS | 0.053 | 0.179 | 0.000 | — | — |
| climb | FAIL | 0.943 | 2.404 | 27.259 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height |
| descend | FAIL | 0.048 | 0.204 | 0.000 | — | transient_height |
| forward | FAIL | 0.859 | 5.413 | 32.038 | 25.450 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| reverse | FAIL | 0.461 | 3.765 | 15.457 | 13.850 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| left | FAIL | 1.131 | 2.827 | 36.299 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| right | FAIL | 0.209 | 3.326 | 28.197 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| forward-left | FAIL | 0.634 | 1.964 | 12.865 | 13.350 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| forward-right | FAIL | 0.787 | 4.224 | 37.934 | 18.250 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, braking |
| reverse-left | FAIL | 0.592 | 1.959 | 22.441 | 13.250 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| reverse-right | FAIL | 0.623 | 2.042 | 13.424 | 13.300 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| turn-left | FAIL | 0.237 | 2.570 | 11.419 | 12.000 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, braking |
| turn-right | FAIL | 0.683 | 2.956 | 18.999 | 11.950 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| climb-forward | FAIL | 0.266 | 1.375 | 12.673 | 18.450 | tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, braking |
| descend-left | FAIL | 0.937 | 2.674 | 23.919 | 40.200 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, braking |
| vertical-cycle | FAIL | 9.944 | 42.692 | 179.583 | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_vertical_rate |
| reverse-command | FAIL | 1.856 | 3.805 | 28.925 | 4.150 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, active_height, motion |
| brake | FAIL | 0.859 | 5.413 | 32.038 | 25.450 | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| slalom | FAIL | 0.388 | 1.677 | 12.229 | 8.700 | tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, motion, braking |
| gust | FAIL | 1.156 | 4.344 | 38.968 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt |
| load-swing | PASS | 0.042 | 0.186 | 2.873 | — | — |
| recovery-diagonal | FAIL | 0.008 | 3.744 | 28.265 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, recovery |
| recovery-inverted | FAIL | 80.039 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/slow-radio-fpv.pdf` et `traces/slow-radio/fpv/`.
