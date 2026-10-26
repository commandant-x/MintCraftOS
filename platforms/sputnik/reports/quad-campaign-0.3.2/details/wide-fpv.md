# wide / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.001 | 0.014 | 0.000 | — | — |
| cold-hover | PASS | 0.005 | 0.022 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.023 | 0.000 | — | — |
| descend | PASS | 0.000 | 0.044 | 0.000 | — | — |
| forward | FAIL | 0.007 | 0.025 | 0.158 | 3.950 | transient_tilt |
| reverse | FAIL | 0.007 | 0.025 | 0.158 | 3.950 | transient_tilt |
| left | PASS | 0.047 | 0.149 | 0.493 | 4.500 | — |
| right | PASS | 0.047 | 0.149 | 0.493 | 4.500 | — |
| forward-left | PASS | 0.026 | 0.110 | 1.373 | 4.500 | — |
| forward-right | PASS | 0.026 | 0.110 | 1.373 | 4.500 | — |
| reverse-left | PASS | 0.026 | 0.110 | 1.373 | 4.500 | — |
| reverse-right | PASS | 0.026 | 0.110 | 1.373 | 4.500 | — |
| turn-left | PASS | 0.022 | 0.063 | 0.465 | 4.450 | — |
| turn-right | PASS | 0.062 | 0.115 | 0.897 | 4.450 | — |
| climb-forward | PASS | 0.009 | 0.026 | 0.768 | 5.050 | — |
| descend-left | FAIL | 0.044 | 0.085 | 0.524 | 4.250 | transient_height |
| vertical-cycle | PASS | 0.005 | 0.020 | 0.000 | — | — |
| reverse-command | PASS | 0.031 | 0.095 | 0.383 | 4.050 | — |
| brake | FAIL | 0.007 | 0.025 | 0.158 | 3.950 | transient_tilt |
| slalom | FAIL | 0.061 | 0.108 | 0.865 | 4.700 | motion |
| gust | PASS | 0.029 | 0.145 | 1.959 | — | — |
| load-swing | PASS | 0.040 | 0.142 | 0.342 | — | — |
| recovery-diagonal | PASS | 0.025 | 0.102 | 0.475 | — | — |
| recovery-inverted | PASS | 0.003 | 0.195 | 0.760 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/wide-fpv.pdf` et `traces/wide/fpv/`.
