# wide / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.008 | 0.000 | — | — |
| cold-hover | PASS | 0.002 | 0.007 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.011 | 0.000 | — | — |
| descend | PASS | 0.001 | 0.010 | 0.000 | — | — |
| forward | PASS | 0.011 | 0.029 | 0.182 | 4.100 | — |
| reverse | PASS | 0.011 | 0.029 | 0.182 | 4.100 | — |
| left | PASS | 0.012 | 0.035 | 0.237 | 4.600 | — |
| right | PASS | 0.012 | 0.035 | 0.237 | 4.600 | — |
| forward-left | PASS | 0.010 | 0.018 | 0.309 | 4.850 | — |
| forward-right | PASS | 0.008 | 0.024 | 0.358 | 4.750 | — |
| reverse-left | PASS | 0.008 | 0.024 | 0.358 | 4.750 | — |
| reverse-right | PASS | 0.010 | 0.018 | 0.309 | 4.850 | — |
| turn-left | PASS | 0.010 | 0.014 | 0.188 | 4.400 | — |
| turn-right | PASS | 0.010 | 0.024 | 0.273 | 4.500 | — |
| climb-forward | PASS | 0.010 | 0.026 | 0.219 | 5.150 | — |
| descend-left | FAIL | 0.023 | 0.032 | 0.319 | 4.350 | transient_height |
| vertical-cycle | PASS | 0.002 | 0.009 | 0.000 | — | — |
| reverse-command | PASS | 0.003 | 0.031 | 0.333 | 4.000 | — |
| brake | PASS | 0.011 | 0.029 | 0.182 | 4.100 | — |
| slalom | PASS | 0.006 | 0.019 | 0.234 | 4.750 | — |
| gust | PASS | 0.001 | 0.025 | 0.161 | — | — |
| load-swing | PASS | 0.015 | 0.031 | 0.282 | — | — |
| recovery-diagonal | PASS | 0.005 | 0.019 | 0.305 | — | — |
| recovery-inverted | PASS | 0.008 | 0.029 | 0.404 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/wide-fpv.pdf` et `traces/wide/fpv/`.
