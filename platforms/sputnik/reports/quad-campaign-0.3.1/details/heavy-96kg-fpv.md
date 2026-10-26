# heavy-96kg / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.004 | 0.009 | 0.000 | — | — |
| cold-hover | PASS | 0.001 | 0.008 | 0.000 | — | — |
| climb | PASS | 0.003 | 0.013 | 0.000 | — | — |
| descend | PASS | 0.002 | 0.044 | 0.000 | — | — |
| forward | FAIL | 0.244 | 0.343 | 0.289 | 7.900 | transient_height, active_height, braking |
| reverse | FAIL | 0.608 | 0.799 | 0.136 | 12.350 | tail_height_peak, tail_height_rms, transient_height, active_height, braking |
| left | FAIL | 0.194 | 0.261 | 0.172 | 7.850 | transient_height, braking |
| right | FAIL | 0.237 | 0.237 | 0.219 | 8.750 | transient_height, braking |
| forward-left | FAIL | 0.315 | 0.364 | 0.150 | 9.550 | transient_height, braking |
| forward-right | FAIL | 0.031 | 0.092 | 0.197 | 6.450 | transient_height, braking |
| reverse-left | FAIL | 0.259 | 0.300 | 0.148 | 8.900 | transient_height, braking |
| reverse-right | FAIL | 0.122 | 0.131 | 0.216 | 7.100 | transient_height, braking |
| turn-left | FAIL | 0.128 | 0.181 | 0.224 | 5.150 | transient_height, active_attitude, active_height |
| turn-right | FAIL | 0.112 | 0.166 | 0.128 | 5.150 | transient_height, active_attitude, active_height |
| climb-forward | FAIL | 0.274 | 0.341 | 0.159 | 10.450 | transient_height, braking |
| descend-left | FAIL | 0.432 | 0.586 | 0.167 | 11.050 | tail_height_peak, tail_height_rms, transient_height, braking |
| vertical-cycle | PASS | 0.001 | 0.012 | 0.000 | — | — |
| reverse-command | FAIL | 0.287 | 0.327 | 0.152 | 7.650 | transient_height, active_height, braking |
| brake | FAIL | 0.244 | 0.343 | 0.289 | 7.900 | transient_height, active_height, braking |
| slalom | FAIL | 0.307 | 0.362 | 0.151 | 6.150 | transient_height, active_attitude, active_height, motion, braking |
| gust | PASS | 0.022 | 0.077 | 0.150 | — | — |
| load-swing | PASS | 0.007 | 0.051 | 0.155 | — | — |
| recovery-diagonal | FAIL | 0.310 | 0.422 | 0.217 | — | tail_height_rms, transient_height, recovery |
| recovery-inverted | FAIL | 0.015 | 0.082 | 0.113 | — | transient_height |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/heavy-96kg-fpv.pdf` et `traces/heavy-96kg/fpv/`.
