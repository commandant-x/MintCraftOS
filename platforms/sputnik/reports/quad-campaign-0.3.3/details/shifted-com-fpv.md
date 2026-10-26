# shifted-com / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.001 | 0.019 | 0.170 | — | — |
| cold-hover | PASS | 0.004 | 0.017 | 0.121 | — | — |
| climb | PASS | 0.002 | 0.026 | 0.176 | — | — |
| descend | PASS | 0.015 | 0.032 | 0.144 | — | — |
| forward | PASS | 0.004 | 0.025 | 0.169 | 4.550 | — |
| reverse | PASS | 0.005 | 0.026 | 0.150 | 4.850 | — |
| left | PASS | 0.010 | 0.020 | 0.139 | 4.100 | — |
| right | PASS | 0.010 | 0.029 | 0.166 | 5.000 | — |
| forward-left | PASS | 0.008 | 0.032 | 0.221 | 4.250 | — |
| forward-right | PASS | 0.005 | 0.032 | 0.180 | 4.950 | — |
| reverse-left | PASS | 0.004 | 0.025 | 0.207 | 4.750 | — |
| reverse-right | PASS | 0.000 | 0.029 | 0.158 | 5.100 | — |
| turn-left | PASS | 0.011 | 0.027 | 0.135 | 4.050 | — |
| turn-right | PASS | 0.004 | 0.027 | 0.152 | 4.650 | — |
| climb-forward | PASS | 0.004 | 0.024 | 0.158 | 5.250 | — |
| descend-left | FAIL | 0.005 | 0.038 | 0.176 | 3.800 | transient_height |
| vertical-cycle | PASS | 0.005 | 0.022 | 0.130 | — | — |
| reverse-command | PASS | 0.012 | 0.034 | 0.155 | 4.200 | — |
| brake | PASS | 0.004 | 0.025 | 0.169 | 4.550 | — |
| slalom | FAIL | 0.003 | 0.025 | 0.130 | 4.600 | active_attitude, motion |
| gust | PASS | 0.003 | 0.027 | 0.133 | — | — |
| load-swing | PASS | 0.017 | 0.020 | 0.174 | — | — |
| recovery-diagonal | PASS | 0.004 | 0.028 | 0.124 | — | — |
| recovery-inverted | PASS | 0.001 | 0.030 | 0.143 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/shifted-com-fpv.pdf` et `traces/shifted-com/fpv/`.
