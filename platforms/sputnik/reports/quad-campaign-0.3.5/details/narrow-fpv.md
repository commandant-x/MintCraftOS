# narrow / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.008 | 0.000 | — | — |
| cold-hover | PASS | 0.001 | 0.007 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.011 | 0.000 | — | — |
| descend | PASS | 0.001 | 0.010 | 0.000 | — | — |
| forward | PASS | 0.005 | 0.030 | 0.392 | 4.700 | — |
| reverse | PASS | 0.005 | 0.030 | 0.392 | 4.700 | — |
| left | PASS | 0.013 | 0.038 | 0.294 | 4.050 | — |
| right | PASS | 0.013 | 0.038 | 0.294 | 4.050 | — |
| forward-left | PASS | 0.000 | 0.035 | 0.260 | 4.800 | — |
| forward-right | PASS | 0.011 | 0.026 | 0.294 | 4.850 | — |
| reverse-left | PASS | 0.011 | 0.026 | 0.294 | 4.850 | — |
| reverse-right | PASS | 0.000 | 0.035 | 0.260 | 4.800 | — |
| turn-left | PASS | 0.010 | 0.027 | 0.315 | 4.150 | — |
| turn-right | PASS | 0.018 | 0.033 | 0.269 | 4.150 | — |
| climb-forward | PASS | 0.014 | 0.031 | 0.251 | 5.100 | — |
| descend-left | FAIL | 0.017 | 0.039 | 0.275 | 3.900 | transient_height |
| vertical-cycle | PASS | 0.002 | 0.009 | 0.000 | — | — |
| reverse-command | PASS | 0.006 | 0.031 | 0.243 | 3.950 | — |
| brake | PASS | 0.005 | 0.030 | 0.392 | 4.700 | — |
| slalom | FAIL | 0.007 | 0.025 | 0.220 | 4.400 | motion |
| gust | PASS | 0.001 | 0.017 | 0.263 | — | — |
| load-swing | PASS | 0.005 | 0.026 | 0.277 | — | — |
| recovery-diagonal | PASS | 0.005 | 0.023 | 0.297 | — | — |
| recovery-inverted | FAIL | 0.116 | 0.134 | 0.235 | — | transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/narrow-fpv.pdf` et `traces/narrow/fpv/`.
