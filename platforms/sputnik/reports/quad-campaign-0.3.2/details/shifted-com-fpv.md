# shifted-com / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.049 | 0.208 | — | — |
| cold-hover | PASS | 0.010 | 0.031 | 0.159 | — | — |
| climb | PASS | 0.005 | 0.025 | 0.129 | — | — |
| descend | PASS | 0.017 | 0.038 | 0.175 | — | — |
| forward | PASS | 0.015 | 0.028 | 0.191 | 4.700 | — |
| reverse | PASS | 0.007 | 0.036 | 0.259 | 4.850 | — |
| left | PASS | 0.002 | 0.035 | 0.184 | 4.100 | — |
| right | PASS | 0.011 | 0.032 | 0.153 | 5.000 | — |
| forward-left | PASS | 0.009 | 0.036 | 0.177 | 4.200 | — |
| forward-right | PASS | 0.001 | 0.025 | 0.139 | 5.000 | — |
| reverse-left | PASS | 0.018 | 0.049 | 0.196 | 4.750 | — |
| reverse-right | PASS | 0.003 | 0.026 | 0.300 | 5.100 | — |
| turn-left | PASS | 0.002 | 0.030 | 0.163 | 4.000 | — |
| turn-right | PASS | 0.000 | 0.022 | 0.219 | 4.700 | — |
| climb-forward | PASS | 0.010 | 0.030 | 0.169 | 5.150 | — |
| descend-left | FAIL | 0.008 | 0.026 | 0.188 | 3.800 | transient_height |
| vertical-cycle | PASS | 0.014 | 0.038 | 0.169 | — | — |
| reverse-command | PASS | 0.003 | 0.029 | 0.183 | 4.250 | — |
| brake | PASS | 0.015 | 0.028 | 0.191 | 4.700 | — |
| slalom | FAIL | 0.013 | 0.035 | 0.185 | 4.600 | active_attitude, motion |
| gust | PASS | 0.004 | 0.022 | 0.159 | — | — |
| load-swing | PASS | 0.002 | 0.023 | 0.152 | — | — |
| recovery-diagonal | PASS | 0.015 | 0.029 | 0.130 | — | — |
| recovery-inverted | FAIL | 0.001 | 0.019 | 0.172 | — | transient_height |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/shifted-com-fpv.pdf` et `traces/shifted-com/fpv/`.
