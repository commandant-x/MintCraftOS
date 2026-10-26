# pressure-mismatch / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.005 | 0.018 | 0.000 | — | — |
| cold-hover | PASS | 0.006 | 0.024 | 0.000 | — | — |
| climb | FAIL | 0.003 | 0.031 | 0.000 | — | transient_height |
| descend | PASS | 0.006 | 0.020 | 0.000 | — | — |
| forward | FAIL | 0.027 | 0.021 | 0.067 | 5.100 | transient_height |
| reverse | FAIL | 0.082 | 0.135 | 0.594 | 5.100 | transient_height |
| left | PASS | 0.018 | 0.236 | 0.742 | 4.950 | — |
| right | PASS | 0.006 | 0.232 | 0.476 | 4.900 | — |
| forward-left | FAIL | 0.169 | 0.241 | 0.830 | 4.900 | transient_height |
| forward-right | FAIL | 0.029 | 0.237 | 0.760 | 4.850 | transient_height |
| reverse-left | FAIL | 0.000 | 0.159 | 0.647 | 4.950 | transient_height |
| reverse-right | FAIL | 0.071 | 0.292 | 0.948 | 4.900 | transient_height |
| turn-left | FAIL | 0.110 | 0.183 | 0.714 | 1.450 | transient_height, active_attitude, active_height |
| turn-right | FAIL | 0.120 | 0.265 | 0.795 | 1.400 | transient_height, active_attitude, active_height |
| climb-forward | FAIL | 0.014 | 0.133 | 0.514 | 6.050 | transient_height, braking |
| descend-left | FAIL | 0.180 | 0.288 | 1.124 | 4.250 | transient_height |
| vertical-cycle | FAIL | 0.004 | 0.024 | 0.000 | — | transient_height |
| reverse-command | FAIL | 0.026 | 0.225 | 0.814 | 3.900 | transient_height, active_height |
| brake | FAIL | 0.027 | 0.021 | 0.067 | 5.100 | transient_height |
| slalom | FAIL | 0.031 | 0.034 | 0.010 | 2.050 | transient_height, active_attitude, active_height, motion |
| gust | PASS | 0.046 | 0.058 | 0.229 | — | — |
| load-swing | PASS | 0.005 | 0.113 | 0.588 | — | — |
| recovery-diagonal | PASS | 0.036 | 0.193 | 0.975 | — | — |
| recovery-inverted | PASS | 0.018 | 0.181 | 0.397 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/pressure-mismatch-fpv.pdf` et `traces/pressure-mismatch/fpv/`.
