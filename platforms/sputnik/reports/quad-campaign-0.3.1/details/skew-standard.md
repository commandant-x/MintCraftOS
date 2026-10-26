# skew / standard

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.030 | 0.094 | 0.196 | — | — |
| cold-hover | PASS | 0.039 | 0.078 | 0.266 | — | — |
| climb | FAIL | 0.027 | 0.088 | 0.175 | — | transient_height |
| descend | FAIL | 0.023 | 0.083 | 0.196 | — | transient_height |
| forward | FAIL | 0.021 | 0.089 | 0.231 | 6.600 | transient_height, active_height, braking |
| reverse | FAIL | 0.013 | 0.078 | 0.210 | 6.250 | transient_height, active_height, braking |
| left | FAIL | 0.026 | 0.098 | 0.155 | 6.900 | transient_height, active_height, braking |
| right | FAIL | 0.020 | 0.053 | 0.194 | 6.800 | transient_height, active_height, braking |
| forward-left | FAIL | 0.036 | 0.091 | 0.299 | 6.950 | transient_height, active_height, braking |
| forward-right | FAIL | 0.056 | 0.106 | 0.281 | 4.300 | transient_height, active_height |
| reverse-left | FAIL | 0.002 | 0.062 | 0.192 | 4.300 | transient_height, active_height |
| reverse-right | FAIL | 0.027 | 0.081 | 0.190 | 7.250 | transient_height, active_height, braking |
| turn-left | FAIL | 0.028 | 0.048 | 0.206 | 3.100 | transient_height, active_attitude, active_height |
| turn-right | FAIL | 0.033 | 0.044 | 0.244 | 4.600 | transient_height, active_attitude, active_height |
| climb-forward | FAIL | 0.049 | 0.090 | 0.170 | 4.800 | transient_height, active_vertical_rate |
| descend-left | FAIL | 0.012 | 0.085 | 0.155 | 5.450 | transient_height |
| vertical-cycle | FAIL | 0.012 | 0.081 | 0.149 | — | transient_height |
| reverse-command | FAIL | 0.010 | 0.041 | 0.211 | 5.450 | transient_height, active_attitude, active_height |
| brake | FAIL | 0.021 | 0.089 | 0.231 | 6.600 | transient_height, active_height, braking |
| slalom | FAIL | 0.020 | 0.087 | 0.204 | 5.350 | active_attitude, active_height, motion |
| gust | PASS | 0.005 | 0.052 | 0.181 | — | — |
| load-swing | FAIL | 0.844 | 0.244 | 2.279 | — | tail_height_rms |
| recovery-diagonal | PASS | 0.007 | 0.062 | 0.245 | — | — |
| recovery-inverted | FAIL | 0.008 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/skew-standard.pdf` et `traces/skew/standard/`.
