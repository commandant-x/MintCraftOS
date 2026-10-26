# narrow / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.005 | 0.021 | 0.000 | — | — |
| cold-hover | PASS | 0.002 | 0.021 | 0.000 | — | — |
| climb | FAIL | 0.012 | 0.024 | 0.000 | — | transient_height |
| descend | PASS | 0.011 | 0.043 | 0.000 | — | — |
| forward | FAIL | 0.055 | 0.241 | 0.949 | 5.800 | transient_height, active_height |
| reverse | FAIL | 0.021 | 0.097 | 0.442 | 5.750 | transient_height, active_height |
| left | PASS | 0.037 | 0.177 | 0.489 | 5.400 | — |
| right | PASS | 0.073 | 0.179 | 0.567 | 4.500 | — |
| forward-left | FAIL | 0.068 | 0.163 | 0.875 | 5.850 | transient_height |
| forward-right | FAIL | 0.056 | 0.210 | 0.771 | 5.900 | transient_height |
| reverse-left | FAIL | 0.063 | 0.207 | 0.587 | 5.900 | transient_height |
| reverse-right | FAIL | 0.077 | 0.112 | 0.642 | 5.850 | transient_height, active_height |
| turn-left | FAIL | 0.065 | 0.248 | 1.286 | 3.500 | transient_height, active_attitude, active_height, motion |
| turn-right | FAIL | 0.017 | 0.157 | 0.426 | 3.550 | transient_height, active_attitude, active_height, motion |
| climb-forward | FAIL | 0.082 | 0.211 | 0.651 | 5.800 | transient_height |
| descend-left | FAIL | 0.084 | 0.205 | 1.170 | 5.100 | transient_height |
| vertical-cycle | FAIL | 0.003 | 0.018 | 0.000 | — | transient_height |
| reverse-command | FAIL | 0.118 | 0.141 | 1.055 | 4.450 | transient_height, active_height |
| brake | FAIL | 0.055 | 0.241 | 0.949 | 5.800 | transient_height, active_height |
| slalom | FAIL | 0.132 | 0.284 | 1.291 | 4.050 | transient_height, active_attitude, active_height, motion |
| gust | PASS | 0.032 | 0.107 | 0.274 | — | — |
| load-swing | PASS | 0.014 | 0.194 | 0.534 | — | — |
| recovery-diagonal | PASS | 0.058 | 0.129 | 1.345 | — | — |
| recovery-inverted | FAIL | 0.137 | 0.258 | 0.603 | — | transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/narrow-fpv.pdf` et `traces/narrow/fpv/`.
