# small-propellers / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.001 | 0.002 | 0.000 | — | — |
| cold-hover | PASS | 0.000 | 0.002 | 0.000 | — | — |
| climb | PASS | 0.004 | 0.005 | 0.000 | — | — |
| descend | PASS | 0.002 | 0.006 | 0.000 | — | — |
| forward | PASS | 0.002 | 0.007 | 0.054 | 4.700 | — |
| reverse | PASS | 0.002 | 0.007 | 0.054 | 4.700 | — |
| left | PASS | 0.003 | 0.005 | 0.054 | 5.100 | — |
| right | PASS | 0.003 | 0.005 | 0.054 | 5.100 | — |
| forward-left | PASS | 0.000 | 0.007 | 0.046 | 5.050 | — |
| forward-right | PASS | 0.000 | 0.013 | 0.056 | 5.050 | — |
| reverse-left | PASS | 0.000 | 0.013 | 0.056 | 5.050 | — |
| reverse-right | PASS | 0.000 | 0.007 | 0.046 | 5.050 | — |
| turn-left | PASS | 0.002 | 0.007 | 0.048 | 5.200 | — |
| turn-right | PASS | 0.001 | 0.007 | 0.064 | 5.150 | — |
| climb-forward | PASS | 0.003 | 0.005 | 0.056 | 5.200 | — |
| descend-left | PASS | 0.003 | 0.008 | 0.054 | 5.050 | — |
| vertical-cycle | PASS | 0.000 | 0.002 | 0.000 | — | — |
| reverse-command | PASS | 0.003 | 0.007 | 0.060 | 3.850 | — |
| brake | PASS | 0.002 | 0.007 | 0.054 | 4.700 | — |
| slalom | PASS | 0.001 | 0.006 | 0.062 | 5.300 | — |
| gust | PASS | 0.000 | 0.008 | 0.071 | — | — |
| load-swing | PASS | 0.009 | 0.007 | 0.051 | — | — |
| recovery-diagonal | PASS | 0.000 | 0.007 | 0.051 | — | — |
| recovery-inverted | FAIL | 0.276 | 0.352 | 0.043 | — | transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/small-propellers-fpv.pdf` et `traces/small-propellers/fpv/`.
