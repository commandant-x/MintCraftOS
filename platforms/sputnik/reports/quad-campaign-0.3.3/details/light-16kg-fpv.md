# light-16kg / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.004 | 0.023 | 0.000 | — | — |
| cold-hover | PASS | 0.007 | 0.023 | 0.000 | — | — |
| climb | FAIL | 0.007 | 0.015 | 0.000 | — | transient_height |
| descend | PASS | 0.019 | 0.044 | 0.000 | — | — |
| forward | FAIL | 0.005 | 0.084 | 0.288 | 4.500 | active_height |
| reverse | FAIL | 0.005 | 0.084 | 0.288 | 4.500 | active_height |
| left | FAIL | 0.009 | 0.075 | 0.227 | 4.700 | active_height |
| right | FAIL | 0.009 | 0.075 | 0.227 | 4.700 | active_height |
| forward-left | FAIL | 0.081 | 0.193 | 0.275 | 4.600 | active_height |
| forward-right | FAIL | 0.024 | 0.181 | 0.438 | 4.800 | active_height |
| reverse-left | FAIL | 0.024 | 0.181 | 0.438 | 4.800 | active_height |
| reverse-right | FAIL | 0.081 | 0.193 | 0.275 | 4.600 | active_height |
| turn-left | FAIL | 0.008 | 0.142 | 0.265 | 4.350 | active_height |
| turn-right | FAIL | 0.026 | 0.126 | 0.208 | 4.500 | active_height |
| climb-forward | PASS | 0.050 | 0.091 | 0.255 | 4.950 | — |
| descend-left | FAIL | 0.030 | 0.136 | 0.343 | 4.600 | transient_height |
| vertical-cycle | FAIL | 0.003 | 0.018 | 0.000 | — | transient_height |
| reverse-command | FAIL | 0.038 | 0.119 | 0.225 | 3.900 | active_height |
| brake | FAIL | 0.005 | 0.084 | 0.288 | 4.500 | active_height |
| slalom | FAIL | 0.024 | 0.125 | 0.312 | 4.400 | active_height, motion |
| gust | PASS | 0.000 | 0.086 | 0.275 | — | — |
| load-swing | PASS | 0.005 | 0.239 | 0.419 | — | — |
| recovery-diagonal | PASS | 0.062 | 0.176 | 0.333 | — | — |
| recovery-inverted | PASS | 0.002 | 0.090 | 0.329 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/light-16kg-fpv.pdf` et `traces/light-16kg/fpv/`.
