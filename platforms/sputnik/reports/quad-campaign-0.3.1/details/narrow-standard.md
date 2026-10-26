# narrow / standard

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.003 | 0.007 | 0.000 | — | — |
| cold-hover | PASS | 0.000 | 0.009 | 0.000 | — | — |
| climb | FAIL | 0.002 | 0.012 | 0.000 | — | transient_height |
| descend | FAIL | 0.007 | 0.017 | 0.000 | — | transient_height |
| forward | FAIL | 0.011 | 0.048 | 0.300 | 7.700 | transient_height, active_height, braking |
| reverse | FAIL | 0.004 | 0.026 | 0.390 | 7.650 | transient_height, active_height, braking |
| left | FAIL | 0.033 | 0.045 | 0.294 | 5.300 | transient_height, active_height |
| right | FAIL | 0.022 | 0.054 | 0.533 | 5.450 | transient_height, active_height |
| forward-left | FAIL | 0.012 | 0.066 | 0.378 | 6.300 | active_height, braking |
| forward-right | FAIL | 0.003 | 0.044 | 0.463 | 6.150 | active_height, braking |
| reverse-left | FAIL | 0.032 | 0.050 | 0.451 | 6.200 | active_height, braking |
| reverse-right | FAIL | 0.006 | 0.052 | 0.343 | 6.250 | active_height, braking |
| turn-left | FAIL | 0.017 | 0.035 | 0.285 | 4.300 | transient_height, active_attitude, active_height |
| turn-right | FAIL | 0.022 | 0.042 | 0.459 | 4.350 | transient_height, active_attitude, active_height |
| climb-forward | FAIL | 0.017 | 0.070 | 0.476 | 4.950 | transient_height, active_vertical_rate |
| descend-left | FAIL | 0.006 | 0.106 | 0.287 | 4.150 | transient_height |
| vertical-cycle | FAIL | 0.026 | 0.047 | 0.000 | — | transient_height |
| reverse-command | FAIL | 0.045 | 0.109 | 0.473 | 3.800 | transient_height, active_attitude, active_height, motion |
| brake | FAIL | 0.011 | 0.048 | 0.300 | 7.700 | transient_height, active_height, braking |
| slalom | FAIL | 0.012 | 0.075 | 0.421 | 5.050 | active_attitude, active_height, motion |
| gust | PASS | 0.001 | 0.062 | 0.441 | — | — |
| load-swing | FAIL | 1.960 | 0.792 | 5.839 | — | tail_height_peak, tail_height_rms, tail_tilt, tail_speed_rms, final_speed |
| recovery-diagonal | PASS | 0.036 | 0.058 | 0.335 | — | — |
| recovery-inverted | FAIL | 0.005 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/narrow-standard.pdf` et `traces/narrow/standard/`.
