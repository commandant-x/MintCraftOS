# skew / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.018 | 0.056 | 0.162 | — | — |
| cold-hover | PASS | 0.007 | 0.052 | 0.120 | — | — |
| climb | FAIL | 0.007 | 0.047 | 0.172 | — | transient_height |
| descend | PASS | 0.001 | 0.044 | 0.191 | — | — |
| forward | FAIL | 0.005 | 0.053 | 0.115 | 5.550 | transient_height |
| reverse | FAIL | 0.001 | 0.044 | 0.135 | 5.250 | transient_height |
| left | FAIL | 0.002 | 0.048 | 0.130 | 4.800 | transient_height |
| right | FAIL | 0.005 | 0.055 | 0.143 | 4.850 | transient_height |
| forward-left | FAIL | 0.026 | 0.040 | 0.141 | 4.950 | transient_height |
| forward-right | FAIL | 0.015 | 0.029 | 0.108 | 5.000 | transient_height |
| reverse-left | FAIL | 0.024 | 0.045 | 0.163 | 4.950 | transient_height |
| reverse-right | FAIL | 0.001 | 0.042 | 0.153 | 5.150 | transient_height |
| turn-left | FAIL | 0.040 | 0.083 | 0.177 | 2.700 | transient_height, active_attitude, active_height, motion |
| turn-right | FAIL | 0.082 | 0.095 | 0.125 | 2.250 | transient_height, active_attitude, active_height, motion |
| climb-forward | FAIL | 0.029 | 0.069 | 0.178 | 5.850 | transient_height |
| descend-left | PASS | 0.009 | 0.039 | 0.130 | 4.450 | — |
| vertical-cycle | FAIL | 0.016 | 0.039 | 0.162 | — | transient_height |
| reverse-command | FAIL | 0.016 | 0.052 | 0.122 | 4.100 | transient_height, active_height |
| brake | FAIL | 0.005 | 0.053 | 0.115 | 5.550 | transient_height |
| slalom | FAIL | 0.030 | 0.067 | 0.120 | 3.350 | transient_height, active_attitude, active_height, motion |
| gust | PASS | 0.009 | 0.054 | 0.135 | — | — |
| load-swing | PASS | 0.018 | 0.063 | 0.203 | — | — |
| recovery-diagonal | PASS | 0.009 | 0.053 | 0.185 | — | — |
| recovery-inverted | PASS | 0.024 | 0.070 | 0.118 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/skew-fpv.pdf` et `traces/skew/fpv/`.
