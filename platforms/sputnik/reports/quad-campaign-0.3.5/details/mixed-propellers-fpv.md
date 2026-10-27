# mixed-propellers / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.071 | 0.157 | 0.714 | — | — |
| cold-hover | PASS | 0.042 | 0.145 | 0.502 | — | — |
| climb | PASS | 0.006 | 0.112 | 0.637 | — | — |
| descend | PASS | 0.005 | 0.156 | 0.779 | — | — |
| forward | PASS | 0.012 | 0.109 | 0.654 | 4.400 | — |
| reverse | FAIL | 0.028 | 0.170 | 0.720 | 4.050 | transient_tilt |
| left | PASS | 0.036 | 0.100 | 0.608 | 5.100 | — |
| right | PASS | 0.044 | 0.138 | 1.039 | 5.200 | — |
| forward-left | PASS | 0.003 | 0.136 | 0.562 | 4.400 | — |
| forward-right | PASS | 0.051 | 0.129 | 0.640 | 5.250 | — |
| reverse-left | PASS | 0.005 | 0.147 | 0.872 | 5.600 | — |
| reverse-right | FAIL | 0.028 | 0.094 | 0.397 | 4.800 | transient_tilt, active_height |
| turn-left | PASS | 0.006 | 0.111 | 0.856 | 4.250 | — |
| turn-right | PASS | 0.006 | 0.086 | 0.434 | 3.900 | — |
| climb-forward | FAIL | 0.056 | 0.166 | 1.352 | 4.750 | transient_height |
| descend-left | PASS | 0.011 | 0.122 | 0.795 | 4.000 | — |
| vertical-cycle | FAIL | 0.041 | 0.156 | 0.856 | — | transient_height |
| reverse-command | PASS | 0.026 | 0.143 | 0.557 | 3.600 | — |
| brake | PASS | 0.012 | 0.109 | 0.654 | 4.400 | — |
| slalom | FAIL | 0.018 | 0.145 | 0.533 | 4.150 | motion |
| gust | PASS | 0.009 | 0.153 | 0.533 | — | — |
| load-swing | PASS | 0.041 | 0.049 | 0.374 | — | — |
| recovery-diagonal | PASS | 0.079 | 0.174 | 1.452 | — | — |
| recovery-inverted | FAIL | 0.053 | 0.121 | 0.557 | — | transient_height |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/mixed-propellers-fpv.pdf` et `traces/mixed-propellers/fpv/`.
