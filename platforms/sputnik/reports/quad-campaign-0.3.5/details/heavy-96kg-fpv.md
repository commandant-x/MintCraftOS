# heavy-96kg / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.001 | 0.004 | 0.000 | — | — |
| cold-hover | PASS | 0.002 | 0.004 | 0.000 | — | — |
| climb | PASS | 0.004 | 0.006 | 0.000 | — | — |
| descend | PASS | 0.001 | 0.013 | 0.000 | — | — |
| forward | PASS | 0.005 | 0.013 | 0.089 | 4.600 | — |
| reverse | PASS | 0.005 | 0.013 | 0.089 | 4.600 | — |
| left | PASS | 0.003 | 0.016 | 0.102 | 4.400 | — |
| right | PASS | 0.003 | 0.016 | 0.102 | 4.400 | — |
| forward-left | PASS | 0.006 | 0.015 | 0.127 | 4.700 | — |
| forward-right | PASS | 0.000 | 0.017 | 0.099 | 4.700 | — |
| reverse-left | PASS | 0.000 | 0.017 | 0.099 | 4.700 | — |
| reverse-right | PASS | 0.006 | 0.015 | 0.127 | 4.700 | — |
| turn-left | PASS | 0.011 | 0.020 | 0.094 | 4.250 | — |
| turn-right | PASS | 0.006 | 0.012 | 0.102 | 4.300 | — |
| climb-forward | PASS | 0.005 | 0.007 | 0.073 | 5.400 | — |
| descend-left | PASS | 0.001 | 0.014 | 0.098 | 4.350 | — |
| vertical-cycle | PASS | 0.001 | 0.004 | 0.000 | — | — |
| reverse-command | PASS | 0.010 | 0.013 | 0.097 | 4.150 | — |
| brake | PASS | 0.005 | 0.013 | 0.089 | 4.600 | — |
| slalom | PASS | 0.000 | 0.011 | 0.111 | 4.450 | — |
| gust | PASS | 0.002 | 0.012 | 0.117 | — | — |
| load-swing | PASS | 0.005 | 0.007 | 0.130 | — | — |
| recovery-diagonal | PASS | 0.003 | 0.018 | 0.085 | — | — |
| recovery-inverted | FAIL | 0.062 | 0.077 | 0.132 | — | transient_height |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/heavy-96kg-fpv.pdf` et `traces/heavy-96kg/fpv/`.
