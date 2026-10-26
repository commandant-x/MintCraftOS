# heavy-96kg / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.001 | 0.004 | 0.000 | — | — |
| cold-hover | PASS | 0.002 | 0.004 | 0.000 | — | — |
| climb | PASS | 0.004 | 0.006 | 0.000 | — | — |
| descend | PASS | 0.001 | 0.013 | 0.000 | — | — |
| forward | PASS | 0.003 | 0.016 | 0.084 | 4.600 | — |
| reverse | PASS | 0.003 | 0.016 | 0.084 | 4.600 | — |
| left | PASS | 0.002 | 0.015 | 0.108 | 4.350 | — |
| right | PASS | 0.002 | 0.015 | 0.108 | 4.350 | — |
| forward-left | PASS | 0.004 | 0.013 | 0.089 | 5.000 | — |
| forward-right | PASS | 0.002 | 0.014 | 0.112 | 5.000 | — |
| reverse-left | PASS | 0.002 | 0.014 | 0.112 | 5.000 | — |
| reverse-right | PASS | 0.004 | 0.013 | 0.089 | 5.000 | — |
| turn-left | PASS | 0.002 | 0.018 | 0.114 | 4.650 | — |
| turn-right | PASS | 0.005 | 0.018 | 0.104 | 4.650 | — |
| climb-forward | PASS | 0.003 | 0.006 | 0.130 | 5.450 | — |
| descend-left | PASS | 0.004 | 0.017 | 0.103 | 4.550 | — |
| vertical-cycle | PASS | 0.001 | 0.004 | 0.000 | — | — |
| reverse-command | PASS | 0.000 | 0.017 | 0.121 | 4.100 | — |
| brake | PASS | 0.003 | 0.016 | 0.084 | 4.600 | — |
| slalom | PASS | 0.001 | 0.016 | 0.105 | 4.700 | — |
| gust | PASS | 0.005 | 0.013 | 0.134 | — | — |
| load-swing | PASS | 0.000 | 0.008 | 0.088 | — | — |
| recovery-diagonal | PASS | 0.002 | 0.015 | 0.102 | — | — |
| recovery-inverted | FAIL | 0.060 | 0.077 | 0.120 | — | transient_height |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/heavy-96kg-fpv.pdf` et `traces/heavy-96kg/fpv/`.
