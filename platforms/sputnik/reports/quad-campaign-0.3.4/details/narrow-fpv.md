# narrow / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.008 | 0.000 | — | — |
| cold-hover | PASS | 0.002 | 0.007 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.011 | 0.000 | — | — |
| descend | PASS | 0.001 | 0.010 | 0.000 | — | — |
| forward | PASS | 0.002 | 0.021 | 0.308 | 4.600 | — |
| reverse | PASS | 0.002 | 0.021 | 0.308 | 4.600 | — |
| left | FAIL | 0.010 | 0.048 | 0.322 | 3.900 | transient_tilt |
| right | FAIL | 0.010 | 0.048 | 0.322 | 3.900 | transient_tilt |
| forward-left | PASS | 0.003 | 0.027 | 0.321 | 4.800 | — |
| forward-right | PASS | 0.005 | 0.036 | 0.203 | 4.850 | — |
| reverse-left | PASS | 0.005 | 0.036 | 0.203 | 4.850 | — |
| reverse-right | PASS | 0.003 | 0.027 | 0.321 | 4.800 | — |
| turn-left | PASS | 0.006 | 0.023 | 0.330 | 3.950 | — |
| turn-right | PASS | 0.012 | 0.027 | 0.343 | 4.100 | — |
| climb-forward | PASS | 0.012 | 0.036 | 0.305 | 5.100 | — |
| descend-left | FAIL | 0.012 | 0.045 | 0.376 | 4.050 | transient_height |
| vertical-cycle | PASS | 0.002 | 0.009 | 0.000 | — | — |
| reverse-command | PASS | 0.014 | 0.033 | 0.383 | 3.900 | — |
| brake | PASS | 0.002 | 0.021 | 0.308 | 4.600 | — |
| slalom | FAIL | 0.009 | 0.036 | 0.302 | 4.300 | motion |
| gust | PASS | 0.004 | 0.025 | 0.295 | — | — |
| load-swing | PASS | 0.003 | 0.050 | 0.246 | — | — |
| recovery-diagonal | PASS | 0.003 | 0.023 | 0.315 | — | — |
| recovery-inverted | FAIL | 0.115 | 0.166 | 0.173 | — | transient_height |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/narrow-fpv.pdf` et `traces/narrow/fpv/`.
