# wide / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.005 | 0.020 | 0.000 | — | — |
| cold-hover | PASS | 0.012 | 0.025 | 0.000 | — | — |
| climb | FAIL | 0.002 | 0.020 | 0.000 | — | transient_height |
| descend | PASS | 0.007 | 0.048 | 0.000 | — | — |
| forward | PASS | 0.029 | 0.161 | 0.964 | 5.350 | — |
| reverse | PASS | 0.030 | 0.179 | 0.483 | 5.300 | — |
| left | FAIL | 0.036 | 0.212 | 0.770 | 5.750 | transient_height, active_height |
| right | FAIL | 0.021 | 0.067 | 0.330 | 5.750 | transient_height, active_height |
| forward-left | FAIL | 0.025 | 0.169 | 0.373 | 5.800 | transient_height |
| forward-right | FAIL | 0.048 | 0.216 | 1.089 | 5.700 | transient_height |
| reverse-left | FAIL | 0.028 | 0.198 | 0.684 | 5.850 | transient_height |
| reverse-right | FAIL | 0.012 | 0.141 | 0.637 | 5.850 | transient_height |
| turn-left | FAIL | 0.080 | 0.172 | 1.057 | 2.800 | transient_height, active_attitude, active_height |
| turn-right | FAIL | 0.156 | 0.132 | 0.238 | 2.000 | transient_height, active_attitude, active_height |
| climb-forward | FAIL | 0.044 | 0.132 | 0.700 | 6.950 | transient_height, braking |
| descend-left | PASS | 0.010 | 0.152 | 1.243 | 5.100 | — |
| vertical-cycle | FAIL | 0.010 | 0.021 | 0.000 | — | transient_height |
| reverse-command | FAIL | 0.017 | 0.219 | 0.893 | 4.050 | active_height |
| brake | PASS | 0.029 | 0.161 | 0.964 | 5.350 | — |
| slalom | FAIL | 0.029 | 0.091 | 0.340 | 3.950 | transient_height, active_attitude, active_height, motion |
| gust | PASS | 0.015 | 0.112 | 0.496 | — | — |
| load-swing | PASS | 0.043 | 0.118 | 0.027 | — | — |
| recovery-diagonal | PASS | 0.041 | 0.123 | 0.946 | — | — |
| recovery-inverted | PASS | 0.006 | 0.148 | 1.334 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/wide-fpv.pdf` et `traces/wide/fpv/`.
