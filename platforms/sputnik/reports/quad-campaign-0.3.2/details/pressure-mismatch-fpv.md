# pressure-mismatch / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.003 | 0.018 | 0.000 | — | — |
| cold-hover | PASS | 0.003 | 0.020 | 0.000 | — | — |
| climb | FAIL | 0.012 | 0.074 | 0.000 | — | transient_height |
| descend | PASS | 0.008 | 0.021 | 0.000 | — | — |
| forward | PASS | 0.024 | 0.024 | 0.021 | 4.700 | — |
| reverse | PASS | 0.024 | 0.024 | 0.021 | 4.700 | — |
| left | PASS | 0.013 | 0.049 | 0.688 | 4.650 | — |
| right | PASS | 0.013 | 0.049 | 0.688 | 4.650 | — |
| forward-left | PASS | 0.005 | 0.022 | 0.019 | 4.750 | — |
| forward-right | PASS | 0.005 | 0.022 | 0.019 | 4.750 | — |
| reverse-left | PASS | 0.005 | 0.022 | 0.019 | 4.750 | — |
| reverse-right | PASS | 0.005 | 0.022 | 0.019 | 4.750 | — |
| turn-left | PASS | 0.016 | 0.026 | 0.030 | 4.500 | — |
| turn-right | PASS | 0.016 | 0.026 | 0.030 | 4.500 | — |
| climb-forward | FAIL | 0.053 | 0.094 | 0.897 | 5.150 | transient_height |
| descend-left | FAIL | 0.036 | 0.149 | 0.726 | 4.650 | transient_height |
| vertical-cycle | FAIL | 0.000 | 0.026 | 0.000 | — | transient_height |
| reverse-command | PASS | 0.011 | 0.030 | 0.048 | 4.000 | — |
| brake | PASS | 0.024 | 0.024 | 0.021 | 4.700 | — |
| slalom | FAIL | 0.023 | 0.159 | 0.767 | 4.600 | motion |
| gust | PASS | 0.032 | 0.116 | 0.930 | — | — |
| load-swing | PASS | 0.026 | 0.145 | 0.764 | — | — |
| recovery-diagonal | PASS | 0.058 | 0.119 | 1.004 | — | — |
| recovery-inverted | PASS | 0.013 | 0.082 | 0.647 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/pressure-mismatch-fpv.pdf` et `traces/pressure-mismatch/fpv/`.
