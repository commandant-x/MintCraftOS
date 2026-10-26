# skew / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.001 | 0.047 | 0.165 | — | — |
| cold-hover | PASS | 0.004 | 0.049 | 0.137 | — | — |
| climb | PASS | 0.000 | 0.058 | 0.128 | — | — |
| descend | PASS | 0.022 | 0.064 | 0.142 | — | — |
| forward | PASS | 0.003 | 0.073 | 0.156 | 4.900 | — |
| reverse | PASS | 0.013 | 0.040 | 0.106 | 4.650 | — |
| left | PASS | 0.004 | 0.047 | 0.123 | 4.800 | — |
| right | PASS | 0.027 | 0.063 | 0.137 | 4.800 | — |
| forward-left | PASS | 0.003 | 0.050 | 0.112 | 4.750 | — |
| forward-right | PASS | 0.002 | 0.041 | 0.138 | 4.800 | — |
| reverse-left | PASS | 0.013 | 0.042 | 0.148 | 4.850 | — |
| reverse-right | PASS | 0.025 | 0.053 | 0.146 | 4.850 | — |
| turn-left | PASS | 0.001 | 0.048 | 0.141 | 4.600 | — |
| turn-right | PASS | 0.002 | 0.052 | 0.156 | 4.650 | — |
| climb-forward | PASS | 0.027 | 0.070 | 0.216 | 5.200 | — |
| descend-left | PASS | 0.006 | 0.040 | 0.222 | 4.200 | — |
| vertical-cycle | PASS | 0.010 | 0.055 | 0.116 | — | — |
| reverse-command | PASS | 0.005 | 0.041 | 0.186 | 3.800 | — |
| brake | PASS | 0.003 | 0.073 | 0.156 | 4.900 | — |
| slalom | FAIL | 0.004 | 0.049 | 0.125 | 4.650 | motion |
| gust | PASS | 0.017 | 0.050 | 0.136 | — | — |
| load-swing | PASS | 0.027 | 0.070 | 0.199 | — | — |
| recovery-diagonal | PASS | 0.000 | 0.037 | 0.159 | — | — |
| recovery-inverted | PASS | 0.027 | 0.064 | 0.126 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/skew-fpv.pdf` et `traces/skew/fpv/`.
