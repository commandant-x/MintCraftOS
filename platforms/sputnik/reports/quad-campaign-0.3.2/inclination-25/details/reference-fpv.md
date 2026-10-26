# reference / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.001 | 0.014 | 0.000 | — | — |
| cold-hover | PASS | 0.005 | 0.022 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.023 | 0.000 | — | — |
| descend | PASS | 0.000 | 0.044 | 0.000 | — | — |
| forward | PASS | 0.088 | 0.159 | 0.630 | 4.550 | — |
| reverse | PASS | 0.088 | 0.159 | 0.630 | 4.550 | — |
| left | FAIL | 0.027 | 0.093 | 0.601 | 5.650 | transient_height, transient_tilt |
| right | FAIL | 0.038 | 0.160 | 1.122 | 5.650 | transient_height, transient_tilt |
| forward-left | PASS | 0.010 | 0.133 | 0.646 | 5.050 | — |
| forward-right | PASS | 0.010 | 0.133 | 0.646 | 5.050 | — |
| reverse-left | PASS | 0.010 | 0.133 | 0.646 | 5.050 | — |
| reverse-right | PASS | 0.010 | 0.133 | 0.646 | 5.050 | — |
| turn-left | PASS | 0.006 | 0.058 | 0.626 | 4.450 | — |
| turn-right | PASS | 0.006 | 0.058 | 0.626 | 4.450 | — |
| climb-forward | PASS | 0.050 | 0.134 | 1.054 | 5.350 | — |
| descend-left | PASS | 0.037 | 0.147 | 0.912 | 4.700 | — |
| vertical-cycle | PASS | 0.005 | 0.020 | 0.000 | — | — |
| reverse-command | PASS | 0.048 | 0.208 | 0.726 | 4.000 | — |
| brake | PASS | 0.088 | 0.159 | 0.630 | 4.550 | — |
| slalom | PASS | 0.010 | 0.168 | 1.135 | 4.600 | — |
| gust | PASS | 0.000 | 0.066 | 0.553 | — | — |
| load-swing | PASS | 0.002 | 0.100 | 0.086 | — | — |
| recovery-diagonal | PASS | 0.010 | 0.116 | 0.941 | — | — |
| recovery-inverted | PASS | 0.006 | 0.023 | 0.015 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/reference-fpv.pdf` et `traces/reference/fpv/`.
