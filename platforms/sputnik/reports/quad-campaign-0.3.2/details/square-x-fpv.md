# square-x / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.001 | 0.014 | 0.000 | — | — |
| cold-hover | PASS | 0.005 | 0.022 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.023 | 0.000 | — | — |
| descend | PASS | 0.000 | 0.044 | 0.000 | — | — |
| forward | PASS | 0.066 | 0.138 | 1.801 | 4.500 | — |
| reverse | PASS | 0.066 | 0.138 | 1.801 | 4.500 | — |
| left | PASS | 0.049 | 0.131 | 1.108 | 4.500 | — |
| right | PASS | 0.049 | 0.131 | 1.108 | 4.500 | — |
| forward-left | PASS | 0.022 | 0.059 | 1.039 | 4.850 | — |
| forward-right | PASS | 0.022 | 0.059 | 1.039 | 4.850 | — |
| reverse-left | PASS | 0.022 | 0.059 | 1.039 | 4.850 | — |
| reverse-right | PASS | 0.022 | 0.059 | 1.039 | 4.850 | — |
| turn-left | PASS | 0.003 | 0.074 | 0.027 | 4.600 | — |
| turn-right | PASS | 0.003 | 0.074 | 0.027 | 4.600 | — |
| climb-forward | PASS | 0.037 | 0.116 | 1.751 | 5.150 | — |
| descend-left | PASS | 0.012 | 0.046 | 0.040 | 4.450 | — |
| vertical-cycle | PASS | 0.005 | 0.020 | 0.000 | — | — |
| reverse-command | PASS | 0.042 | 0.234 | 2.090 | 4.100 | — |
| brake | PASS | 0.066 | 0.138 | 1.801 | 4.500 | — |
| slalom | FAIL | 0.012 | 0.064 | 0.068 | 4.600 | motion |
| gust | PASS | 0.002 | 0.035 | 0.045 | — | — |
| load-swing | PASS | 0.019 | 0.218 | 1.033 | — | — |
| recovery-diagonal | PASS | 0.037 | 0.179 | 1.646 | — | — |
| recovery-inverted | PASS | 0.089 | 0.125 | 1.362 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/square-x-fpv.pdf` et `traces/square-x/fpv/`.
