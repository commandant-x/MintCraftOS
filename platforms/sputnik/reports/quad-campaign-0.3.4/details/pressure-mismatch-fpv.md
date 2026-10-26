# pressure-mismatch / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.003 | 0.010 | 0.000 | — | — |
| cold-hover | PASS | 0.003 | 0.009 | 0.000 | — | — |
| climb | FAIL | 0.000 | 0.010 | 0.000 | — | transient_height |
| descend | PASS | 0.002 | 0.016 | 0.000 | — | — |
| forward | PASS | 0.006 | 0.030 | 0.316 | 4.750 | — |
| reverse | PASS | 0.006 | 0.030 | 0.316 | 4.750 | — |
| left | PASS | 0.007 | 0.030 | 0.225 | 4.700 | — |
| right | PASS | 0.007 | 0.030 | 0.225 | 4.700 | — |
| forward-left | PASS | 0.033 | 0.085 | 0.371 | 4.700 | — |
| forward-right | PASS | 0.012 | 0.033 | 0.240 | 4.700 | — |
| reverse-left | PASS | 0.012 | 0.033 | 0.240 | 4.700 | — |
| reverse-right | PASS | 0.033 | 0.085 | 0.371 | 4.700 | — |
| turn-left | PASS | 0.014 | 0.066 | 0.309 | 4.350 | — |
| turn-right | PASS | 0.025 | 0.051 | 0.362 | 4.400 | — |
| climb-forward | FAIL | 0.000 | 0.020 | 0.186 | 5.300 | transient_height |
| descend-left | FAIL | 0.002 | 0.058 | 0.388 | 4.100 | transient_height |
| vertical-cycle | FAIL | 0.001 | 0.011 | 0.000 | — | transient_height |
| reverse-command | PASS | 0.005 | 0.048 | 0.286 | 4.100 | — |
| brake | PASS | 0.006 | 0.030 | 0.316 | 4.750 | — |
| slalom | FAIL | 0.007 | 0.039 | 0.260 | 4.500 | motion |
| gust | PASS | 0.005 | 0.028 | 0.215 | — | — |
| load-swing | PASS | 0.027 | 0.032 | 0.146 | — | — |
| recovery-diagonal | PASS | 0.015 | 0.088 | 0.397 | — | — |
| recovery-inverted | PASS | 0.013 | 0.032 | 0.242 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/pressure-mismatch-fpv.pdf` et `traces/pressure-mismatch/fpv/`.
