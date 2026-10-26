# paired-rotors / standard

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | FAIL | 0.231 | 1.302 | 0.000 | — | tail_height_span, tail_speed_rms, final_speed |
| cold-hover | FAIL | 0.008 | 3.030 | 0.000 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_speed_rms, final_speed |
| climb | FAIL | 0.046 | 1.313 | 0.000 | — | tail_height_span, tail_speed_rms, final_speed, transient_height, active_vertical_rate |
| descend | FAIL | 0.850 | 3.850 | 0.000 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_speed_rms, final_speed, transient_height |
| forward | FAIL | 0.036 | 0.378 | 0.719 | 13.350 | transient_height, active_attitude, active_height, braking |
| reverse | FAIL | 0.106 | 0.453 | 1.084 | 13.450 | transient_height, active_attitude, active_height, braking |
| left | FAIL | 0.088 | 0.361 | 0.747 | 16.500 | transient_height, active_height, braking |
| right | FAIL | 0.230 | 0.413 | 0.476 | 14.150 | transient_height, active_height, braking |
| forward-left | FAIL | 0.193 | 0.343 | 0.600 | 13.550 | transient_height, active_height, braking |
| forward-right | FAIL | 0.079 | 0.311 | 0.837 | 5.100 | transient_height, active_height |
| reverse-left | FAIL | 0.055 | 0.382 | 0.653 | 10.900 | transient_height, active_height, braking |
| reverse-right | FAIL | 0.073 | 0.291 | 0.706 | 14.750 | transient_height, active_height, braking |
| turn-left | FAIL | 0.192 | 0.387 | 0.660 | 5.350 | transient_height, active_attitude, active_height |
| turn-right | FAIL | 0.049 | 0.396 | 0.731 | 7.700 | transient_height, active_attitude, active_height, motion, braking |
| climb-forward | FAIL | 0.136 | 0.350 | 0.480 | 5.300 | transient_height, active_vertical_rate, motion |
| descend-left | FAIL | 0.122 | 0.885 | 1.540 | 20.000 | transient_height, active_attitude, active_vertical_rate, braking |
| vertical-cycle | FAIL | 1.467 | 2.898 | 0.000 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_speed_rms, final_speed, transient_height, active_vertical_rate |
| reverse-command | FAIL | 0.280 | 1.074 | 1.985 | 10.750 | tail_height_span, transient_height, active_attitude, active_height, braking |
| brake | FAIL | 0.036 | 0.378 | 0.719 | 13.350 | transient_height, active_attitude, active_height, braking |
| slalom | FAIL | 0.125 | 0.392 | 0.794 | 10.550 | transient_height, active_attitude, active_height, motion, braking |
| gust | PASS | 0.129 | 0.374 | 0.542 | — | — |
| load-swing | FAIL | 29.101 | 5.895 | 29.322 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height |
| recovery-diagonal | FAIL | 0.013 | 0.502 | 0.851 | — | recovery |
| recovery-inverted | FAIL | 0.068 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/paired-rotors-standard.pdf` et `traces/paired-rotors/standard/`.
