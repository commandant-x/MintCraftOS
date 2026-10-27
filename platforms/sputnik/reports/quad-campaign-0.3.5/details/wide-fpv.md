# wide / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.008 | 0.000 | — | — |
| cold-hover | PASS | 0.001 | 0.007 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.011 | 0.000 | — | — |
| descend | PASS | 0.001 | 0.010 | 0.000 | — | — |
| forward | PASS | 0.003 | 0.023 | 0.278 | 4.100 | — |
| reverse | PASS | 0.003 | 0.023 | 0.278 | 4.100 | — |
| left | PASS | 0.026 | 0.033 | 0.298 | 4.650 | — |
| right | PASS | 0.026 | 0.033 | 0.298 | 4.650 | — |
| forward-left | PASS | 0.018 | 0.029 | 0.260 | 4.850 | — |
| forward-right | PASS | 0.013 | 0.029 | 0.261 | 4.850 | — |
| reverse-left | PASS | 0.013 | 0.029 | 0.261 | 4.850 | — |
| reverse-right | PASS | 0.018 | 0.029 | 0.260 | 4.850 | — |
| turn-left | PASS | 0.016 | 0.031 | 0.228 | 4.450 | — |
| turn-right | PASS | 0.006 | 0.012 | 0.176 | 4.450 | — |
| climb-forward | PASS | 0.011 | 0.023 | 0.191 | 5.150 | — |
| descend-left | FAIL | 0.002 | 0.028 | 0.227 | 4.150 | transient_height |
| vertical-cycle | PASS | 0.002 | 0.009 | 0.000 | — | — |
| reverse-command | PASS | 0.006 | 0.021 | 0.241 | 3.950 | — |
| brake | PASS | 0.003 | 0.023 | 0.278 | 4.100 | — |
| slalom | PASS | 0.005 | 0.031 | 0.288 | 4.550 | — |
| gust | PASS | 0.012 | 0.023 | 0.305 | — | — |
| load-swing | PASS | 0.006 | 0.031 | 0.249 | — | — |
| recovery-diagonal | PASS | 0.006 | 0.023 | 0.310 | — | — |
| recovery-inverted | PASS | 0.006 | 0.031 | 0.289 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/wide-fpv.pdf` et `traces/wide/fpv/`.
