# heavy-96kg / standard

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.003 | 0.009 | 0.000 | — | — |
| cold-hover | PASS | 0.001 | 0.009 | 0.000 | — | — |
| climb | FAIL | 0.005 | 0.017 | 0.000 | — | transient_height |
| descend | FAIL | 0.008 | 0.016 | 0.000 | — | transient_height |
| forward | FAIL | 0.010 | 0.018 | 0.123 | 6.500 | braking |
| reverse | FAIL | 0.009 | 0.019 | 0.121 | 6.500 | braking |
| left | FAIL | 0.004 | 0.023 | 0.124 | 6.700 | braking |
| right | FAIL | 0.002 | 0.018 | 0.121 | 6.750 | braking |
| forward-left | FAIL | 0.003 | 0.018 | 0.170 | 6.600 | braking |
| forward-right | FAIL | 0.002 | 0.020 | 0.175 | 6.600 | braking |
| reverse-left | FAIL | 0.001 | 0.018 | 0.179 | 6.500 | braking |
| reverse-right | FAIL | 0.010 | 0.026 | 0.114 | 6.600 | braking |
| turn-left | FAIL | 0.001 | 0.021 | 0.131 | 3.200 | active_attitude |
| turn-right | FAIL | 0.013 | 0.019 | 0.169 | 3.250 | active_attitude |
| climb-forward | FAIL | 0.010 | 0.017 | 0.129 | 7.000 | transient_height, braking |
| descend-left | FAIL | 0.004 | 0.027 | 0.266 | 5.950 | transient_height |
| vertical-cycle | FAIL | 0.020 | 0.047 | 0.000 | — | transient_height |
| reverse-command | PASS | 0.007 | 0.019 | 0.140 | 5.600 | — |
| brake | FAIL | 0.010 | 0.018 | 0.123 | 6.500 | braking |
| slalom | FAIL | 0.000 | 0.029 | 0.128 | 5.700 | active_attitude, motion |
| gust | PASS | 0.005 | 0.024 | 0.165 | — | — |
| load-swing | PASS | 0.002 | 0.013 | 0.160 | — | — |
| recovery-diagonal | PASS | 0.011 | 0.025 | 0.170 | — | — |
| recovery-inverted | FAIL | 0.003 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/heavy-96kg-standard.pdf` et `traces/heavy-96kg/standard/`.
