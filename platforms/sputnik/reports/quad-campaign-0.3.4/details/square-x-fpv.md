# square-x / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.008 | 0.000 | — | — |
| cold-hover | PASS | 0.002 | 0.007 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.011 | 0.000 | — | — |
| descend | PASS | 0.001 | 0.010 | 0.000 | — | — |
| forward | PASS | 0.001 | 0.027 | 0.398 | 4.500 | — |
| reverse | PASS | 0.001 | 0.027 | 0.398 | 4.500 | — |
| left | PASS | 0.001 | 0.024 | 0.365 | 4.450 | — |
| right | PASS | 0.001 | 0.024 | 0.365 | 4.450 | — |
| forward-left | PASS | 0.011 | 0.023 | 0.190 | 4.200 | — |
| forward-right | PASS | 0.001 | 0.015 | 0.292 | 4.450 | — |
| reverse-left | PASS | 0.001 | 0.015 | 0.292 | 4.450 | — |
| reverse-right | PASS | 0.011 | 0.023 | 0.190 | 4.200 | — |
| turn-left | PASS | 0.013 | 0.026 | 0.193 | 4.150 | — |
| turn-right | PASS | 0.009 | 0.035 | 0.261 | 4.200 | — |
| climb-forward | PASS | 0.005 | 0.023 | 0.234 | 5.250 | — |
| descend-left | PASS | 0.006 | 0.015 | 0.235 | 3.450 | — |
| vertical-cycle | PASS | 0.002 | 0.009 | 0.000 | — | — |
| reverse-command | PASS | 0.020 | 0.030 | 0.235 | 4.050 | — |
| brake | PASS | 0.001 | 0.027 | 0.398 | 4.500 | — |
| slalom | FAIL | 0.003 | 0.022 | 0.347 | 4.250 | motion |
| gust | PASS | 0.009 | 0.014 | 0.255 | — | — |
| load-swing | PASS | 0.012 | 0.027 | 0.230 | — | — |
| recovery-diagonal | PASS | 0.004 | 0.019 | 0.245 | — | — |
| recovery-inverted | PASS | 0.022 | 0.017 | 0.310 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/square-x-fpv.pdf` et `traces/square-x/fpv/`.
