# small-propellers / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.001 | 0.002 | 0.000 | — | — |
| cold-hover | PASS | 0.000 | 0.002 | 0.000 | — | — |
| climb | PASS | 0.004 | 0.005 | 0.000 | — | — |
| descend | PASS | 0.002 | 0.006 | 0.000 | — | — |
| forward | PASS | 0.001 | 0.004 | 0.049 | 5.250 | — |
| reverse | PASS | 0.001 | 0.004 | 0.049 | 5.250 | — |
| left | PASS | 0.002 | 0.004 | 0.057 | 5.050 | — |
| right | PASS | 0.002 | 0.004 | 0.057 | 5.050 | — |
| forward-left | PASS | 0.002 | 0.010 | 0.058 | 5.100 | — |
| forward-right | PASS | 0.001 | 0.004 | 0.059 | 5.050 | — |
| reverse-left | PASS | 0.001 | 0.004 | 0.059 | 5.050 | — |
| reverse-right | PASS | 0.002 | 0.010 | 0.058 | 5.100 | — |
| turn-left | PASS | 0.001 | 0.005 | 0.056 | 5.200 | — |
| turn-right | PASS | 0.000 | 0.005 | 0.063 | 5.200 | — |
| climb-forward | PASS | 0.003 | 0.005 | 0.052 | 5.950 | — |
| descend-left | PASS | 0.006 | 0.009 | 0.045 | 5.300 | — |
| vertical-cycle | PASS | 0.000 | 0.002 | 0.000 | — | — |
| reverse-command | PASS | 0.001 | 0.005 | 0.061 | 3.850 | — |
| brake | PASS | 0.001 | 0.004 | 0.049 | 5.250 | — |
| slalom | PASS | 0.001 | 0.006 | 0.056 | 4.650 | — |
| gust | PASS | 0.001 | 0.004 | 0.061 | — | — |
| load-swing | PASS | 0.004 | 0.006 | 0.044 | — | — |
| recovery-diagonal | PASS | 0.001 | 0.005 | 0.048 | — | — |
| recovery-inverted | FAIL | 0.225 | 0.284 | 0.037 | — | transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/small-propellers-fpv.pdf` et `traces/small-propellers/fpv/`.
