# square-x / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.008 | 0.000 | — | — |
| cold-hover | PASS | 0.002 | 0.007 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.011 | 0.000 | — | — |
| descend | PASS | 0.001 | 0.010 | 0.000 | — | — |
| forward | PASS | 0.004 | 0.027 | 0.251 | 4.550 | — |
| reverse | PASS | 0.004 | 0.027 | 0.251 | 4.550 | — |
| left | PASS | 0.002 | 0.023 | 0.357 | 4.550 | — |
| right | PASS | 0.002 | 0.023 | 0.357 | 4.550 | — |
| forward-left | PASS | 0.009 | 0.026 | 0.164 | 4.900 | — |
| forward-right | PASS | 0.006 | 0.017 | 0.330 | 4.900 | — |
| reverse-left | PASS | 0.006 | 0.017 | 0.330 | 4.900 | — |
| reverse-right | PASS | 0.009 | 0.026 | 0.164 | 4.900 | — |
| turn-left | PASS | 0.009 | 0.022 | 0.339 | 4.650 | — |
| turn-right | PASS | 0.004 | 0.023 | 0.273 | 4.600 | — |
| climb-forward | PASS | 0.002 | 0.014 | 0.404 | 5.250 | — |
| descend-left | PASS | 0.014 | 0.030 | 0.251 | 4.400 | — |
| vertical-cycle | PASS | 0.002 | 0.009 | 0.000 | — | — |
| reverse-command | PASS | 0.000 | 0.024 | 0.303 | 4.050 | — |
| brake | PASS | 0.004 | 0.027 | 0.251 | 4.550 | — |
| slalom | FAIL | 0.001 | 0.013 | 0.235 | 4.600 | motion |
| gust | PASS | 0.004 | 0.015 | 0.379 | — | — |
| load-swing | PASS | 0.003 | 0.016 | 0.233 | — | — |
| recovery-diagonal | PASS | 0.005 | 0.013 | 0.224 | — | — |
| recovery-inverted | PASS | 0.005 | 0.028 | 0.325 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/square-x-fpv.pdf` et `traces/square-x/fpv/`.
