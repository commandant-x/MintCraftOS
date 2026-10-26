# modular-24 / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.013 | 0.055 | 0.000 | — | — |
| cold-hover | PASS | 0.022 | 0.082 | 0.000 | — | — |
| climb | FAIL | 0.002 | 0.016 | 0.000 | — | transient_height |
| descend | PASS | 0.008 | 0.020 | 0.000 | — | — |
| forward | FAIL | 0.052 | 0.084 | 0.282 | 4.650 | active_height |
| reverse | FAIL | 0.052 | 0.084 | 0.282 | 4.650 | active_height |
| left | FAIL | 0.017 | 0.143 | 0.535 | 4.650 | active_height |
| right | FAIL | 0.017 | 0.143 | 0.535 | 4.650 | active_height |
| forward-left | FAIL | 0.102 | 0.149 | 0.300 | 5.750 | active_height |
| forward-right | FAIL | 0.032 | 0.173 | 0.342 | 5.600 | active_height |
| reverse-left | FAIL | 0.032 | 0.173 | 0.342 | 5.600 | active_height |
| reverse-right | FAIL | 0.102 | 0.149 | 0.300 | 5.750 | active_height |
| turn-left | FAIL | 0.070 | 0.201 | 0.274 | 4.750 | active_height |
| turn-right | FAIL | 0.050 | 0.082 | 0.283 | 4.650 | active_height |
| climb-forward | FAIL | 0.004 | 0.078 | 0.244 | 5.350 | transient_height |
| descend-left | FAIL | 0.119 | 0.279 | 0.328 | 4.450 | transient_height |
| vertical-cycle | FAIL | 0.013 | 0.060 | 0.000 | — | transient_height |
| reverse-command | FAIL | 0.018 | 0.092 | 0.248 | 3.300 | active_height |
| brake | FAIL | 0.052 | 0.084 | 0.282 | 4.650 | active_height |
| slalom | FAIL | 0.041 | 0.127 | 0.334 | 4.650 | active_height, motion |
| gust | PASS | 0.007 | 0.122 | 0.492 | — | — |
| load-swing | PASS | 0.036 | 0.127 | 0.439 | — | — |
| recovery-diagonal | PASS | 0.012 | 0.061 | 0.388 | — | — |
| recovery-inverted | FAIL | 0.052 | 0.140 | 0.227 | — | transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/modular-24-fpv.pdf` et `traces/modular-24/fpv/`.
