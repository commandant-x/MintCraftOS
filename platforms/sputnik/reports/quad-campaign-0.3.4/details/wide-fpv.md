# wide / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.008 | 0.000 | — | — |
| cold-hover | PASS | 0.002 | 0.007 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.011 | 0.000 | — | — |
| descend | PASS | 0.001 | 0.010 | 0.000 | — | — |
| forward | FAIL | 0.010 | 0.040 | 0.210 | 4.450 | transient_tilt |
| reverse | FAIL | 0.010 | 0.040 | 0.210 | 4.450 | transient_tilt |
| left | PASS | 0.006 | 0.021 | 0.334 | 4.600 | — |
| right | PASS | 0.006 | 0.021 | 0.334 | 4.600 | — |
| forward-left | PASS | 0.010 | 0.018 | 0.298 | 4.900 | — |
| forward-right | PASS | 0.004 | 0.041 | 0.358 | 4.800 | — |
| reverse-left | PASS | 0.004 | 0.041 | 0.358 | 4.800 | — |
| reverse-right | PASS | 0.010 | 0.018 | 0.298 | 4.900 | — |
| turn-left | PASS | 0.010 | 0.013 | 0.207 | 4.500 | — |
| turn-right | PASS | 0.018 | 0.027 | 0.276 | 4.400 | — |
| climb-forward | PASS | 0.000 | 0.018 | 0.318 | 5.100 | — |
| descend-left | FAIL | 0.016 | 0.033 | 0.275 | 4.250 | transient_height |
| vertical-cycle | PASS | 0.002 | 0.009 | 0.000 | — | — |
| reverse-command | FAIL | 0.006 | 0.031 | 0.330 | 3.950 | transient_tilt |
| brake | FAIL | 0.010 | 0.040 | 0.210 | 4.450 | transient_tilt |
| slalom | PASS | 0.007 | 0.022 | 0.305 | 4.550 | — |
| gust | PASS | 0.014 | 0.030 | 0.243 | — | — |
| load-swing | PASS | 0.016 | 0.049 | 0.451 | — | — |
| recovery-diagonal | PASS | 0.001 | 0.019 | 0.326 | — | — |
| recovery-inverted | PASS | 0.003 | 0.026 | 0.395 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/wide-fpv.pdf` et `traces/wide/fpv/`.
