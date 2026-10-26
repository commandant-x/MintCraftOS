# coupled-inertia / standard

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.009 | 0.000 | — | — |
| cold-hover | PASS | 0.001 | 0.009 | 0.000 | — | — |
| climb | FAIL | 0.004 | 0.012 | 0.000 | — | transient_height |
| descend | FAIL | 0.009 | 0.019 | 0.000 | — | transient_height |
| forward | FAIL | 0.026 | 0.051 | 0.370 | 9.700 | transient_height, active_height, braking |
| reverse | FAIL | 0.016 | 0.089 | 0.369 | 9.900 | transient_height, active_height, braking |
| left | FAIL | 0.001 | 0.068 | 0.400 | 5.550 | transient_height, active_height |
| right | FAIL | 0.018 | 0.089 | 0.444 | 5.550 | transient_height, active_height |
| forward-left | FAIL | 0.002 | 0.070 | 0.367 | 8.750 | transient_height, active_height, braking |
| forward-right | FAIL | 0.014 | 0.088 | 0.306 | 7.350 | transient_height, active_height, braking |
| reverse-left | FAIL | 0.061 | 0.100 | 0.341 | 6.450 | transient_height, active_height, braking |
| reverse-right | FAIL | 0.009 | 0.065 | 0.565 | 8.350 | transient_height, active_height, braking |
| turn-left | FAIL | 0.035 | 0.048 | 0.504 | 5.700 | transient_height, active_attitude, active_height |
| turn-right | FAIL | 0.014 | 0.070 | 0.292 | 6.300 | transient_height, active_attitude, active_height, braking |
| climb-forward | FAIL | 0.015 | 0.071 | 0.319 | 5.450 | transient_height, active_vertical_rate |
| descend-left | FAIL | 0.039 | 0.107 | 0.600 | 7.750 | transient_height, braking |
| vertical-cycle | FAIL | 0.022 | 0.049 | 0.000 | — | transient_height |
| reverse-command | FAIL | 0.008 | 0.026 | 0.329 | 9.100 | transient_height, active_attitude, active_height, braking |
| brake | FAIL | 0.026 | 0.051 | 0.370 | 9.700 | transient_height, active_height, braking |
| slalom | FAIL | 0.001 | 0.070 | 0.457 | 4.300 | transient_height, active_attitude, active_height, motion |
| gust | PASS | 0.043 | 0.085 | 0.254 | — | — |
| load-swing | FAIL | 0.627 | 0.055 | 1.071 | — | tail_height_rms |
| recovery-diagonal | PASS | 0.012 | 0.089 | 0.280 | — | — |
| recovery-inverted | FAIL | 0.008 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/coupled-inertia-standard.pdf` et `traces/coupled-inertia/standard/`.
