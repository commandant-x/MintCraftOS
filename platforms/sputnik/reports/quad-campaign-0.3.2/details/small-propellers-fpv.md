# small-propellers / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.001 | 0.004 | 0.000 | — | — |
| cold-hover | PASS | 0.000 | 0.004 | 0.000 | — | — |
| climb | PASS | 0.003 | 0.006 | 0.000 | — | — |
| descend | PASS | 0.002 | 0.006 | 0.000 | — | — |
| forward | PASS | 0.005 | 0.021 | 0.064 | 4.750 | — |
| reverse | PASS | 0.005 | 0.021 | 0.064 | 4.750 | — |
| left | PASS | 0.011 | 0.024 | 0.111 | 5.050 | — |
| right | PASS | 0.011 | 0.024 | 0.111 | 5.050 | — |
| forward-left | PASS | 0.001 | 0.018 | 0.102 | 5.050 | — |
| forward-right | PASS | 0.001 | 0.018 | 0.102 | 5.050 | — |
| reverse-left | PASS | 0.001 | 0.018 | 0.102 | 5.050 | — |
| reverse-right | PASS | 0.001 | 0.018 | 0.102 | 5.050 | — |
| turn-left | PASS | 0.007 | 0.024 | 0.101 | 5.150 | — |
| turn-right | PASS | 0.007 | 0.024 | 0.101 | 5.150 | — |
| climb-forward | PASS | 0.005 | 0.018 | 0.049 | 5.900 | — |
| descend-left | PASS | 0.004 | 0.008 | 0.042 | 5.300 | — |
| vertical-cycle | PASS | 0.001 | 0.004 | 0.000 | — | — |
| reverse-command | PASS | 0.012 | 0.030 | 0.095 | 3.850 | — |
| brake | PASS | 0.005 | 0.021 | 0.064 | 4.750 | — |
| slalom | PASS | 0.003 | 0.016 | 0.071 | 4.650 | — |
| gust | PASS | 0.003 | 0.014 | 0.131 | — | — |
| load-swing | PASS | 0.003 | 0.012 | 0.045 | — | — |
| recovery-diagonal | PASS | 0.005 | 0.021 | 0.080 | — | — |
| recovery-inverted | FAIL | 0.229 | 0.293 | 0.079 | — | transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/small-propellers-fpv.pdf` et `traces/small-propellers/fpv/`.
