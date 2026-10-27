# skew / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.004 | 0.046 | 0.102 | — | — |
| cold-hover | PASS | 0.020 | 0.058 | 0.153 | — | — |
| climb | PASS | 0.017 | 0.057 | 0.143 | — | — |
| descend | PASS | 0.004 | 0.038 | 0.118 | — | — |
| forward | PASS | 0.010 | 0.036 | 0.139 | 4.600 | — |
| reverse | PASS | 0.012 | 0.056 | 0.132 | 4.650 | — |
| left | PASS | 0.006 | 0.044 | 0.155 | 4.600 | — |
| right | PASS | 0.003 | 0.041 | 0.172 | 4.750 | — |
| forward-left | PASS | 0.006 | 0.049 | 0.101 | 4.750 | — |
| forward-right | PASS | 0.002 | 0.049 | 0.156 | 4.800 | — |
| reverse-left | PASS | 0.003 | 0.037 | 0.117 | 4.500 | — |
| reverse-right | PASS | 0.002 | 0.048 | 0.168 | 4.750 | — |
| turn-left | PASS | 0.006 | 0.050 | 0.162 | 4.450 | — |
| turn-right | PASS | 0.000 | 0.051 | 0.115 | 4.500 | — |
| climb-forward | PASS | 0.002 | 0.043 | 0.125 | 5.300 | — |
| descend-left | PASS | 0.002 | 0.047 | 0.228 | 3.950 | — |
| vertical-cycle | PASS | 0.009 | 0.059 | 0.136 | — | — |
| reverse-command | PASS | 0.017 | 0.032 | 0.132 | 4.100 | — |
| brake | PASS | 0.010 | 0.036 | 0.139 | 4.600 | — |
| slalom | PASS | 0.016 | 0.037 | 0.109 | 4.450 | — |
| gust | PASS | 0.008 | 0.047 | 0.185 | — | — |
| load-swing | PASS | 0.025 | 0.047 | 0.244 | — | — |
| recovery-diagonal | PASS | 0.004 | 0.063 | 0.194 | — | — |
| recovery-inverted | PASS | 0.025 | 0.053 | 0.141 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/skew-fpv.pdf` et `traces/skew/fpv/`.
