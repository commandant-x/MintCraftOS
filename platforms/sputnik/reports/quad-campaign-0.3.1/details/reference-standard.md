# reference / standard

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.009 | 0.000 | — | — |
| cold-hover | PASS | 0.001 | 0.009 | 0.000 | — | — |
| climb | FAIL | 0.004 | 0.012 | 0.000 | — | transient_height |
| descend | FAIL | 0.009 | 0.019 | 0.000 | — | transient_height |
| forward | FAIL | 0.007 | 0.073 | 0.559 | 11.150 | transient_height, active_height, braking |
| reverse | FAIL | 0.002 | 0.034 | 0.315 | 11.350 | transient_height, active_height, braking |
| left | FAIL | 0.007 | 0.034 | 0.425 | 5.650 | transient_height, active_height |
| right | FAIL | 0.015 | 0.035 | 0.463 | 5.550 | transient_height, active_height |
| forward-left | FAIL | 0.010 | 0.030 | 0.275 | 9.000 | transient_height, active_height, braking |
| forward-right | FAIL | 0.022 | 0.069 | 0.462 | 9.100 | transient_height, active_height, braking |
| reverse-left | FAIL | 0.015 | 0.097 | 0.414 | 9.000 | transient_height, active_height, braking |
| reverse-right | FAIL | 0.012 | 0.060 | 0.377 | 8.700 | transient_height, active_height, braking |
| turn-left | FAIL | 0.011 | 0.041 | 0.398 | 6.650 | transient_height, active_attitude, active_height, braking |
| turn-right | FAIL | 0.040 | 0.051 | 0.406 | 6.800 | transient_height, active_attitude, active_height, braking |
| climb-forward | FAIL | 0.000 | 0.053 | 0.491 | 5.250 | transient_height, active_vertical_rate |
| descend-left | FAIL | 0.005 | 0.065 | 0.460 | 7.850 | transient_height, braking |
| vertical-cycle | FAIL | 0.022 | 0.049 | 0.000 | — | transient_height |
| reverse-command | FAIL | 0.010 | 0.043 | 0.449 | 7.800 | transient_height, active_attitude, active_height, braking |
| brake | FAIL | 0.007 | 0.073 | 0.559 | 11.150 | transient_height, active_height, braking |
| slalom | FAIL | 0.016 | 0.060 | 0.338 | 4.500 | transient_height, active_attitude, active_height, motion |
| gust | PASS | 0.021 | 0.076 | 0.297 | — | — |
| load-swing | FAIL | 0.650 | 0.064 | 0.586 | — | tail_height_rms |
| recovery-diagonal | PASS | 0.005 | 0.080 | 0.291 | — | — |
| recovery-inverted | FAIL | 0.008 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/reference-standard.pdf` et `traces/reference/standard/`.
