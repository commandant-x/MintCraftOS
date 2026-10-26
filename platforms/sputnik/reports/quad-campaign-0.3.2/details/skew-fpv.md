# skew / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.001 | 0.047 | 0.165 | — | — |
| cold-hover | PASS | 0.017 | 0.044 | 0.130 | — | — |
| climb | PASS | 0.005 | 0.051 | 0.130 | — | — |
| descend | PASS | 0.011 | 0.065 | 0.170 | — | — |
| forward | PASS | 0.023 | 0.075 | 0.135 | 4.900 | — |
| reverse | PASS | 0.013 | 0.040 | 0.106 | 4.650 | — |
| left | PASS | 0.004 | 0.047 | 0.123 | 4.800 | — |
| right | PASS | 0.014 | 0.042 | 0.128 | 4.700 | — |
| forward-left | PASS | 0.003 | 0.050 | 0.112 | 4.750 | — |
| forward-right | PASS | 0.012 | 0.051 | 0.193 | 4.800 | — |
| reverse-left | PASS | 0.013 | 0.042 | 0.148 | 4.850 | — |
| reverse-right | PASS | 0.010 | 0.049 | 0.134 | 4.750 | — |
| turn-left | PASS | 0.001 | 0.048 | 0.141 | 4.600 | — |
| turn-right | PASS | 0.016 | 0.041 | 0.124 | 4.650 | — |
| climb-forward | PASS | 0.030 | 0.057 | 0.201 | 5.200 | — |
| descend-left | PASS | 0.008 | 0.039 | 0.139 | 4.350 | — |
| vertical-cycle | PASS | 0.016 | 0.043 | 0.154 | — | — |
| reverse-command | PASS | 0.012 | 0.038 | 0.095 | 3.850 | — |
| brake | PASS | 0.023 | 0.075 | 0.135 | 4.900 | — |
| slalom | FAIL | 0.013 | 0.038 | 0.122 | 4.650 | motion |
| gust | PASS | 0.011 | 0.060 | 0.117 | — | — |
| load-swing | PASS | 0.007 | 0.106 | 0.240 | — | — |
| recovery-diagonal | PASS | 0.000 | 0.037 | 0.159 | — | — |
| recovery-inverted | PASS | 0.028 | 0.056 | 0.167 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/skew-fpv.pdf` et `traces/skew/fpv/`.
