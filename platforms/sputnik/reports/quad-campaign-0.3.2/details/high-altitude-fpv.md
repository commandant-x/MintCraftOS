# high-altitude / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.025 | 0.077 | 2.342 | — | — |
| cold-hover | PASS | 0.024 | 0.062 | 2.344 | — | — |
| climb | PASS | 0.005 | 0.057 | 2.273 | — | — |
| descend | PASS | 0.000 | 0.059 | 2.326 | — | — |
| forward | PASS | 0.018 | 0.086 | 2.298 | 4.550 | — |
| reverse | PASS | 0.028 | 0.047 | 2.377 | 5.000 | — |
| left | PASS | 0.009 | 0.070 | 2.323 | 4.300 | — |
| right | PASS | 0.010 | 0.066 | 2.273 | 5.150 | — |
| forward-left | PASS | 0.012 | 0.071 | 2.293 | 4.400 | — |
| forward-right | PASS | 0.005 | 0.030 | 2.279 | 5.150 | — |
| reverse-left | PASS | 0.007 | 0.046 | 2.274 | 4.800 | — |
| reverse-right | PASS | 0.010 | 0.045 | 2.328 | 5.500 | — |
| turn-left | PASS | 0.021 | 0.071 | 2.284 | 4.050 | — |
| turn-right | PASS | 0.019 | 0.045 | 2.366 | 4.900 | — |
| climb-forward | PASS | 0.013 | 0.056 | 2.277 | 5.150 | — |
| descend-left | PASS | 0.031 | 0.088 | 2.260 | 4.100 | — |
| vertical-cycle | FAIL | 0.013 | 0.085 | 2.407 | — | active_attitude |
| reverse-command | PASS | 0.003 | 0.052 | 2.250 | 4.500 | — |
| brake | PASS | 0.018 | 0.086 | 2.298 | 4.550 | — |
| slalom | FAIL | 0.010 | 0.073 | 2.308 | 4.800 | active_attitude, motion |
| gust | PASS | 0.036 | 0.085 | 2.328 | — | — |
| load-swing | PASS | 0.024 | 0.129 | 2.609 | — | — |
| recovery-diagonal | PASS | 0.032 | 0.079 | 2.351 | — | — |
| recovery-inverted | FAIL | 0.065 | 0.094 | 2.385 | — | transient_height |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/high-altitude-fpv.pdf` et `traces/high-altitude/fpv/`.
