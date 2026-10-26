# heavy-96kg / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.001 | 0.007 | 0.000 | — | — |
| cold-hover | PASS | 0.001 | 0.010 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.011 | 0.000 | — | — |
| descend | PASS | 0.003 | 0.042 | 0.000 | — | — |
| forward | PASS | 0.009 | 0.089 | 0.237 | 4.500 | — |
| reverse | PASS | 0.009 | 0.089 | 0.237 | 4.500 | — |
| left | PASS | 0.019 | 0.045 | 0.393 | 4.350 | — |
| right | PASS | 0.019 | 0.045 | 0.393 | 4.350 | — |
| forward-left | PASS | 0.014 | 0.065 | 0.248 | 5.000 | — |
| forward-right | PASS | 0.014 | 0.065 | 0.248 | 5.000 | — |
| reverse-left | PASS | 0.014 | 0.065 | 0.248 | 5.000 | — |
| reverse-right | PASS | 0.014 | 0.065 | 0.248 | 5.000 | — |
| turn-left | PASS | 0.002 | 0.032 | 0.308 | 4.650 | — |
| turn-right | PASS | 0.002 | 0.032 | 0.308 | 4.650 | — |
| climb-forward | PASS | 0.014 | 0.035 | 0.265 | 5.450 | — |
| descend-left | PASS | 0.041 | 0.056 | 0.329 | 4.600 | — |
| vertical-cycle | PASS | 0.000 | 0.011 | 0.000 | — | — |
| reverse-command | PASS | 0.015 | 0.053 | 0.272 | 4.150 | — |
| brake | PASS | 0.009 | 0.089 | 0.237 | 4.500 | — |
| slalom | PASS | 0.004 | 0.039 | 0.257 | 4.700 | — |
| gust | PASS | 0.002 | 0.046 | 0.262 | — | — |
| load-swing | PASS | 0.010 | 0.038 | 0.195 | — | — |
| recovery-diagonal | PASS | 0.002 | 0.048 | 0.229 | — | — |
| recovery-inverted | FAIL | 0.076 | 0.113 | 0.254 | — | transient_height |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/heavy-96kg-fpv.pdf` et `traces/heavy-96kg/fpv/`.
