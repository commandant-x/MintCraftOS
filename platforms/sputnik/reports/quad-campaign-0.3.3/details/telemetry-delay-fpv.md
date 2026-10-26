# telemetry-delay / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.013 | 0.024 | 0.358 | — | — |
| cold-hover | PASS | 0.002 | 0.041 | 0.474 | — | — |
| climb | FAIL | 0.007 | 0.017 | 0.226 | — | transient_height |
| descend | PASS | 0.019 | 0.055 | 0.466 | — | — |
| forward | PASS | 0.007 | 0.030 | 0.298 | 4.550 | — |
| reverse | PASS | 0.026 | 0.038 | 0.355 | 4.600 | — |
| left | PASS | 0.007 | 0.038 | 0.398 | 6.000 | — |
| right | FAIL | 0.002 | 0.033 | 0.298 | 6.200 | braking |
| forward-left | FAIL | 0.000 | 0.055 | 0.239 | 6.450 | braking |
| forward-right | FAIL | 0.012 | 0.040 | 0.321 | 6.250 | braking |
| reverse-left | FAIL | 0.019 | 0.031 | 0.298 | 6.250 | braking |
| reverse-right | FAIL | 0.023 | 0.031 | 0.387 | 6.500 | braking |
| turn-left | FAIL | 0.009 | 0.043 | 0.396 | 6.150 | braking |
| turn-right | FAIL | 0.016 | 0.030 | 0.286 | 6.100 | braking |
| climb-forward | FAIL | 0.026 | 0.048 | 0.466 | 5.550 | transient_height |
| descend-left | FAIL | 0.034 | 0.073 | 0.550 | 4.500 | transient_height, active_attitude |
| vertical-cycle | FAIL | 0.001 | 0.011 | 0.000 | — | transient_height |
| reverse-command | PASS | 0.025 | 0.049 | 0.452 | 3.250 | — |
| brake | PASS | 0.007 | 0.030 | 0.298 | 4.550 | — |
| slalom | FAIL | 0.015 | 0.035 | 0.280 | 5.950 | motion |
| gust | PASS | 0.010 | 0.017 | 0.259 | — | — |
| load-swing | FAIL | 0.114 | 0.137 | 13.394 | — | tail_tilt, tail_speed_rms, final_speed |
| recovery-diagonal | PASS | 0.004 | 0.034 | 0.375 | — | — |
| recovery-inverted | FAIL | 0.006 | 0.021 | 0.329 | — | transient_height |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/telemetry-delay-fpv.pdf` et `traces/telemetry-delay/fpv/`.
