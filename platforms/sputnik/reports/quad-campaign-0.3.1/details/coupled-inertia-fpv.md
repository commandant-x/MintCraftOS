# coupled-inertia / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.004 | 0.025 | 0.000 | — | — |
| cold-hover | PASS | 0.006 | 0.018 | 0.000 | — | — |
| climb | FAIL | 0.007 | 0.023 | 0.000 | — | transient_height |
| descend | PASS | 0.010 | 0.043 | 0.000 | — | — |
| forward | PASS | 0.124 | 0.181 | 0.612 | 4.750 | — |
| reverse | PASS | 0.024 | 0.150 | 0.841 | 4.650 | — |
| left | FAIL | 0.036 | 0.152 | 0.574 | 6.600 | transient_height, braking |
| right | FAIL | 0.059 | 0.207 | 0.586 | 6.750 | transient_height, braking |
| forward-left | FAIL | 0.054 | 0.146 | 0.500 | 4.800 | transient_height |
| forward-right | FAIL | 0.155 | 0.220 | 0.461 | 5.050 | transient_height |
| reverse-left | FAIL | 0.071 | 0.250 | 1.441 | 5.000 | transient_height |
| reverse-right | FAIL | 0.039 | 0.119 | 0.529 | 5.050 | transient_height |
| turn-left | FAIL | 0.035 | 0.172 | 0.800 | 3.650 | transient_height, active_attitude, active_height, motion |
| turn-right | FAIL | 0.059 | 0.182 | 0.695 | 5.350 | transient_height, active_attitude, active_height, motion |
| climb-forward | FAIL | 0.023 | 0.110 | 0.716 | 5.450 | transient_height |
| descend-left | PASS | 0.005 | 0.195 | 0.767 | 4.250 | — |
| vertical-cycle | FAIL | 0.005 | 0.016 | 0.000 | — | transient_height |
| reverse-command | FAIL | 0.017 | 0.235 | 0.760 | 3.800 | active_height |
| brake | PASS | 0.124 | 0.181 | 0.612 | 4.750 | — |
| slalom | FAIL | 0.045 | 0.191 | 0.370 | 2.550 | transient_height, active_attitude, active_height, motion |
| gust | PASS | 0.067 | 0.127 | 0.641 | — | — |
| load-swing | PASS | 0.097 | 0.231 | 0.960 | — | — |
| recovery-diagonal | PASS | 0.018 | 0.172 | 0.758 | — | — |
| recovery-inverted | FAIL | 0.097 | 0.177 | 1.034 | — | recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/coupled-inertia-fpv.pdf` et `traces/coupled-inertia/fpv/`.
