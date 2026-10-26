# low-inertia / standard

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.001 | 0.009 | 0.000 | — | — |
| cold-hover | PASS | 0.001 | 0.009 | 0.000 | — | — |
| climb | FAIL | 0.002 | 0.011 | 0.000 | — | transient_height |
| descend | FAIL | 0.009 | 0.019 | 0.000 | — | transient_height |
| forward | FAIL | 0.021 | 0.098 | 0.570 | 10.300 | transient_height, active_height, braking |
| reverse | FAIL | 0.038 | 0.152 | 0.522 | 10.300 | transient_height, active_height, braking |
| left | FAIL | 0.015 | 0.210 | 0.846 | 12.500 | transient_height, transient_tilt, active_height, braking |
| right | FAIL | 0.035 | 0.179 | 0.493 | 12.600 | transient_height, transient_tilt, active_height, braking |
| forward-left | FAIL | 0.030 | 0.221 | 0.568 | 11.650 | transient_height, active_height, braking |
| forward-right | FAIL | 0.043 | 0.227 | 0.676 | 11.750 | transient_height, active_height, braking |
| reverse-left | FAIL | 0.001 | 0.095 | 0.640 | 11.650 | transient_height, active_height, braking |
| reverse-right | FAIL | 0.055 | 0.146 | 0.716 | 11.650 | transient_height, active_height, braking |
| turn-left | FAIL | 0.037 | 0.150 | 0.488 | 4.450 | transient_height, active_attitude, active_height |
| turn-right | FAIL | 0.137 | 0.171 | 0.529 | 5.350 | transient_height, active_attitude, active_height, motion |
| climb-forward | FAIL | 0.069 | 0.227 | 0.568 | 10.700 | transient_height, active_vertical_rate, braking |
| descend-left | FAIL | 0.100 | 0.234 | 1.307 | 8.700 | transient_height, active_attitude, braking |
| vertical-cycle | FAIL | 0.026 | 0.042 | 0.000 | — | transient_height |
| reverse-command | FAIL | 0.084 | 0.217 | 0.737 | 12.100 | transient_height, active_attitude, active_height, motion, braking |
| brake | FAIL | 0.021 | 0.098 | 0.570 | 10.300 | transient_height, active_height, braking |
| slalom | FAIL | 0.018 | 0.232 | 1.063 | 9.750 | active_attitude, active_height, motion, braking |
| gust | PASS | 0.118 | 0.195 | 0.581 | — | — |
| load-swing | FAIL | 0.590 | 0.105 | 0.564 | — | tail_height_rms |
| recovery-diagonal | PASS | 0.088 | 0.195 | 0.577 | — | — |
| recovery-inverted | FAIL | 0.008 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/low-inertia-standard.pdf` et `traces/low-inertia/standard/`.
