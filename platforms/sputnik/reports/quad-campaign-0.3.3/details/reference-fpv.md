# reference / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.008 | 0.000 | — | — |
| cold-hover | PASS | 0.002 | 0.007 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.011 | 0.000 | — | — |
| descend | PASS | 0.001 | 0.010 | 0.000 | — | — |
| forward | PASS | 0.007 | 0.019 | 0.187 | 4.550 | — |
| reverse | PASS | 0.007 | 0.019 | 0.187 | 4.550 | — |
| left | PASS | 0.003 | 0.033 | 0.147 | 3.600 | — |
| right | PASS | 0.003 | 0.033 | 0.147 | 3.600 | — |
| forward-left | PASS | 0.008 | 0.038 | 0.265 | 4.850 | — |
| forward-right | PASS | 0.002 | 0.027 | 0.204 | 4.900 | — |
| reverse-left | PASS | 0.002 | 0.027 | 0.204 | 4.900 | — |
| reverse-right | PASS | 0.008 | 0.038 | 0.265 | 4.850 | — |
| turn-left | PASS | 0.007 | 0.020 | 0.204 | 4.500 | — |
| turn-right | PASS | 0.019 | 0.021 | 0.211 | 4.500 | — |
| climb-forward | PASS | 0.013 | 0.028 | 0.171 | 5.100 | — |
| descend-left | PASS | 0.027 | 0.032 | 0.201 | 4.600 | — |
| vertical-cycle | PASS | 0.002 | 0.009 | 0.000 | — | — |
| reverse-command | PASS | 0.003 | 0.039 | 0.169 | 3.750 | — |
| brake | PASS | 0.007 | 0.019 | 0.187 | 4.550 | — |
| slalom | PASS | 0.020 | 0.028 | 0.221 | 4.400 | — |
| gust | PASS | 0.002 | 0.024 | 0.174 | — | — |
| load-swing | PASS | 0.017 | 0.040 | 0.334 | — | — |
| recovery-diagonal | PASS | 0.000 | 0.030 | 0.201 | — | — |
| recovery-inverted | PASS | 0.005 | 0.017 | 0.257 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/reference-fpv.pdf` et `traces/reference/fpv/`.
