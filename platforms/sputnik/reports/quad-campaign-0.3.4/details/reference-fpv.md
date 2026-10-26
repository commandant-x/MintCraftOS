# reference / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.008 | 0.000 | — | — |
| cold-hover | PASS | 0.002 | 0.007 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.011 | 0.000 | — | — |
| descend | PASS | 0.001 | 0.010 | 0.000 | — | — |
| forward | PASS | 0.003 | 0.028 | 0.189 | 4.500 | — |
| reverse | PASS | 0.003 | 0.028 | 0.189 | 4.500 | — |
| left | PASS | 0.012 | 0.020 | 0.345 | 3.650 | — |
| right | PASS | 0.012 | 0.020 | 0.345 | 3.650 | — |
| forward-left | PASS | 0.018 | 0.053 | 0.292 | 4.650 | — |
| forward-right | PASS | 0.008 | 0.019 | 0.262 | 4.650 | — |
| reverse-left | PASS | 0.008 | 0.019 | 0.262 | 4.650 | — |
| reverse-right | PASS | 0.018 | 0.053 | 0.292 | 4.650 | — |
| turn-left | PASS | 0.008 | 0.024 | 0.165 | 4.250 | — |
| turn-right | PASS | 0.015 | 0.017 | 0.179 | 4.200 | — |
| climb-forward | PASS | 0.002 | 0.030 | 0.191 | 5.050 | — |
| descend-left | PASS | 0.018 | 0.023 | 0.316 | 3.900 | — |
| vertical-cycle | PASS | 0.002 | 0.009 | 0.000 | — | — |
| reverse-command | PASS | 0.022 | 0.023 | 0.228 | 3.850 | — |
| brake | PASS | 0.003 | 0.028 | 0.189 | 4.500 | — |
| slalom | PASS | 0.017 | 0.023 | 0.206 | 4.150 | — |
| gust | PASS | 0.011 | 0.023 | 0.175 | — | — |
| load-swing | PASS | 0.024 | 0.036 | 0.208 | — | — |
| recovery-diagonal | PASS | 0.010 | 0.028 | 0.316 | — | — |
| recovery-inverted | PASS | 0.011 | 0.031 | 0.191 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/reference-fpv.pdf` et `traces/reference/fpv/`.
