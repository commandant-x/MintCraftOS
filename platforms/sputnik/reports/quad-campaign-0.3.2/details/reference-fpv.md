# reference / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.001 | 0.014 | 0.000 | — | — |
| cold-hover | PASS | 0.005 | 0.022 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.023 | 0.000 | — | — |
| descend | PASS | 0.000 | 0.044 | 0.000 | — | — |
| forward | PASS | 0.014 | 0.100 | 0.807 | 4.500 | — |
| reverse | PASS | 0.014 | 0.100 | 0.807 | 4.500 | — |
| left | PASS | 0.006 | 0.025 | 0.007 | 3.850 | — |
| right | PASS | 0.006 | 0.025 | 0.007 | 3.850 | — |
| forward-left | PASS | 0.033 | 0.106 | 1.000 | 4.850 | — |
| forward-right | PASS | 0.033 | 0.106 | 1.000 | 4.850 | — |
| reverse-left | PASS | 0.033 | 0.106 | 1.000 | 4.850 | — |
| reverse-right | PASS | 0.033 | 0.106 | 1.000 | 4.850 | — |
| turn-left | PASS | 0.112 | 0.232 | 0.790 | 4.500 | — |
| turn-right | PASS | 0.112 | 0.232 | 0.790 | 4.500 | — |
| climb-forward | PASS | 0.005 | 0.038 | 0.333 | 5.050 | — |
| descend-left | PASS | 0.024 | 0.124 | 1.257 | 4.550 | — |
| vertical-cycle | PASS | 0.005 | 0.020 | 0.000 | — | — |
| reverse-command | PASS | 0.009 | 0.023 | 0.032 | 3.750 | — |
| brake | PASS | 0.014 | 0.100 | 0.807 | 4.500 | — |
| slalom | PASS | 0.015 | 0.138 | 0.812 | 4.400 | — |
| gust | PASS | 0.000 | 0.066 | 0.553 | — | — |
| load-swing | PASS | 0.002 | 0.100 | 0.086 | — | — |
| recovery-diagonal | PASS | 0.058 | 0.179 | 1.547 | — | — |
| recovery-inverted | PASS | 0.023 | 0.085 | 1.014 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/reference-fpv.pdf` et `traces/reference/fpv/`.
