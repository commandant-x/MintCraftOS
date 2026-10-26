# wide / standard

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.000 | 0.008 | 0.000 | — | — |
| cold-hover | PASS | 0.003 | 0.008 | 0.000 | — | — |
| climb | FAIL | 0.003 | 0.011 | 0.000 | — | transient_height |
| descend | FAIL | 0.010 | 0.022 | 0.000 | — | transient_height |
| forward | FAIL | 0.005 | 0.054 | 0.481 | 5.450 | transient_height, active_height |
| reverse | FAIL | 0.005 | 0.061 | 0.535 | 5.500 | transient_height, active_height |
| left | FAIL | 0.001 | 0.031 | 0.420 | 7.600 | transient_height, active_height, braking |
| right | FAIL | 0.015 | 0.044 | 0.525 | 7.800 | transient_height, active_height, braking |
| forward-left | FAIL | 0.002 | 0.061 | 0.324 | 6.350 | active_height, braking |
| forward-right | FAIL | 0.012 | 0.060 | 0.508 | 6.150 | active_height, braking |
| reverse-left | FAIL | 0.023 | 0.084 | 0.405 | 6.350 | active_height, braking |
| reverse-right | FAIL | 0.000 | 0.083 | 0.330 | 6.050 | active_height, braking |
| turn-left | FAIL | 0.012 | 0.095 | 0.539 | 4.800 | transient_height, active_attitude, active_height |
| turn-right | FAIL | 0.003 | 0.028 | 0.316 | 4.750 | transient_height, active_attitude, active_height |
| climb-forward | FAIL | 0.001 | 0.077 | 0.442 | 4.750 | transient_height, active_vertical_rate |
| descend-left | FAIL | 0.037 | 0.102 | 0.419 | 5.900 | transient_height, active_attitude, active_vertical_rate |
| vertical-cycle | FAIL | 0.025 | 0.046 | 0.000 | — | transient_height |
| reverse-command | FAIL | 0.038 | 0.100 | 0.452 | 3.200 | transient_height, active_height |
| brake | FAIL | 0.005 | 0.054 | 0.481 | 5.450 | transient_height, active_height |
| slalom | FAIL | 0.011 | 0.062 | 0.516 | 4.600 | active_attitude, active_height, motion |
| gust | PASS | 0.015 | 0.045 | 0.436 | — | — |
| load-swing | FAIL | 13.590 | 2.817 | 18.983 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height |
| recovery-diagonal | PASS | 0.021 | 0.073 | 0.364 | — | — |
| recovery-inverted | FAIL | 0.004 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/wide-standard.pdf` et `traces/wide/standard/`.
