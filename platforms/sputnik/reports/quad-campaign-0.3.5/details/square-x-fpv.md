# square-x / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.008 | 0.000 | — | — |
| cold-hover | PASS | 0.001 | 0.007 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.011 | 0.000 | — | — |
| descend | PASS | 0.001 | 0.010 | 0.000 | — | — |
| forward | PASS | 0.013 | 0.020 | 0.207 | 4.550 | — |
| reverse | PASS | 0.013 | 0.020 | 0.207 | 4.550 | — |
| left | PASS | 0.003 | 0.024 | 0.200 | 4.550 | — |
| right | PASS | 0.003 | 0.024 | 0.200 | 4.550 | — |
| forward-left | PASS | 0.016 | 0.021 | 0.230 | 4.200 | — |
| forward-right | PASS | 0.003 | 0.022 | 0.269 | 4.500 | — |
| reverse-left | PASS | 0.003 | 0.022 | 0.269 | 4.500 | — |
| reverse-right | PASS | 0.016 | 0.021 | 0.230 | 4.200 | — |
| turn-left | PASS | 0.012 | 0.011 | 0.248 | 4.300 | — |
| turn-right | PASS | 0.002 | 0.035 | 0.229 | 4.250 | — |
| climb-forward | PASS | 0.003 | 0.021 | 0.287 | 5.200 | — |
| descend-left | PASS | 0.001 | 0.023 | 0.315 | 3.400 | — |
| vertical-cycle | PASS | 0.002 | 0.009 | 0.000 | — | — |
| reverse-command | PASS | 0.011 | 0.013 | 0.216 | 4.050 | — |
| brake | PASS | 0.013 | 0.020 | 0.207 | 4.550 | — |
| slalom | FAIL | 0.009 | 0.028 | 0.261 | 4.300 | motion |
| gust | PASS | 0.010 | 0.016 | 0.197 | — | — |
| load-swing | PASS | 0.008 | 0.015 | 0.237 | — | — |
| recovery-diagonal | PASS | 0.002 | 0.016 | 0.228 | — | — |
| recovery-inverted | PASS | 0.004 | 0.022 | 0.277 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/square-x-fpv.pdf` et `traces/square-x/fpv/`.
