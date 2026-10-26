# square-x / standard

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.004 | 0.010 | 0.000 | — | — |
| cold-hover | PASS | 0.001 | 0.007 | 0.000 | — | — |
| climb | FAIL | 0.004 | 0.011 | 0.000 | — | transient_height |
| descend | FAIL | 0.005 | 0.022 | 0.000 | — | transient_height |
| forward | FAIL | 0.010 | 0.108 | 0.455 | 6.250 | transient_height, active_height, braking |
| reverse | FAIL | 0.007 | 0.080 | 0.400 | 6.250 | transient_height, active_height, braking |
| left | FAIL | 0.006 | 0.087 | 0.460 | 6.300 | transient_height, active_height, braking |
| right | FAIL | 0.023 | 0.113 | 0.564 | 6.250 | transient_height, active_height, braking |
| forward-left | FAIL | 0.014 | 0.052 | 0.341 | 7.100 | transient_height, active_height, braking |
| forward-right | FAIL | 0.011 | 0.031 | 0.457 | 7.050 | transient_height, active_height, braking |
| reverse-left | FAIL | 0.022 | 0.055 | 0.265 | 7.000 | transient_height, active_height, braking |
| reverse-right | FAIL | 0.010 | 0.060 | 0.334 | 7.100 | transient_height, active_height, braking |
| turn-left | FAIL | 0.001 | 0.061 | 0.411 | 3.000 | active_attitude, active_height |
| turn-right | FAIL | 0.016 | 0.079 | 0.309 | 3.000 | active_attitude, active_height |
| climb-forward | FAIL | 0.018 | 0.033 | 0.360 | 5.700 | transient_height, active_vertical_rate |
| descend-left | FAIL | 0.019 | 0.046 | 0.372 | 4.850 | transient_height, active_attitude |
| vertical-cycle | FAIL | 0.023 | 0.047 | 0.000 | — | transient_height |
| reverse-command | FAIL | 0.026 | 0.044 | 0.335 | 5.200 | transient_height, active_attitude, active_height, motion |
| brake | FAIL | 0.010 | 0.108 | 0.455 | 6.250 | transient_height, active_height, braking |
| slalom | FAIL | 0.002 | 0.039 | 0.263 | 4.950 | active_attitude, active_height, motion |
| gust | PASS | 0.035 | 0.074 | 0.363 | — | — |
| load-swing | FAIL | 0.623 | 0.057 | 0.585 | — | tail_height_rms |
| recovery-diagonal | PASS | 0.005 | 0.048 | 0.295 | — | — |
| recovery-inverted | FAIL | 0.004 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/square-x-standard.pdf` et `traces/square-x/standard/`.
