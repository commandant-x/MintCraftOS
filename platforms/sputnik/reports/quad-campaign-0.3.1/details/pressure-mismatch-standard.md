# pressure-mismatch / standard

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.007 | 0.000 | — | — |
| cold-hover | PASS | 0.003 | 0.012 | 0.000 | — | — |
| climb | FAIL | 0.002 | 0.017 | 0.000 | — | transient_height, active_vertical_rate |
| descend | FAIL | 0.016 | 0.021 | 0.000 | — | transient_height |
| forward | FAIL | 0.027 | 0.080 | 0.521 | 4.550 | transient_height, active_height |
| reverse | FAIL | 0.007 | 0.055 | 0.357 | 4.550 | transient_height, active_height |
| left | FAIL | 0.004 | 0.092 | 0.545 | 4.450 | transient_height, active_height |
| right | FAIL | 0.042 | 0.099 | 0.505 | 4.500 | transient_height, active_height |
| forward-left | FAIL | 0.022 | 0.094 | 0.590 | 4.500 | transient_height, active_height |
| forward-right | FAIL | 0.004 | 0.064 | 0.545 | 4.500 | transient_height, active_height |
| reverse-left | FAIL | 0.060 | 0.122 | 0.552 | 4.400 | transient_height, active_height |
| reverse-right | FAIL | 0.022 | 0.069 | 0.340 | 4.500 | transient_height, active_height |
| turn-left | FAIL | 0.024 | 0.071 | 0.519 | 4.500 | transient_height, active_attitude, active_height |
| turn-right | FAIL | 0.031 | 0.100 | 0.576 | 4.700 | transient_height, active_attitude, active_height, motion |
| climb-forward | FAIL | 0.002 | 0.215 | 0.665 | 6.050 | transient_height, active_vertical_rate, braking |
| descend-left | FAIL | 0.035 | 0.040 | 0.469 | 6.800 | transient_height, braking |
| vertical-cycle | FAIL | 0.032 | 0.077 | 0.000 | — | transient_height, active_vertical_rate |
| reverse-command | FAIL | 0.037 | 0.092 | 0.515 | 5.300 | transient_height, active_height |
| brake | FAIL | 0.027 | 0.080 | 0.521 | 4.550 | transient_height, active_height |
| slalom | FAIL | 0.005 | 0.069 | 0.307 | 5.450 | transient_height, active_attitude, active_height, motion |
| gust | PASS | 0.060 | 0.093 | 0.558 | — | — |
| load-swing | FAIL | 2.535 | 0.039 | 0.685 | — | tail_height_peak, tail_height_rms |
| recovery-diagonal | PASS | 0.017 | 0.092 | 0.413 | — | — |
| recovery-inverted | FAIL | 1.007 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/pressure-mismatch-standard.pdf` et `traces/pressure-mismatch/standard/`.
