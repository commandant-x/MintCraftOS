# modular-24 / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.013 | 0.055 | 0.000 | — | — |
| cold-hover | PASS | 0.022 | 0.082 | 0.000 | — | — |
| climb | FAIL | 0.002 | 0.016 | 0.000 | — | transient_height |
| descend | PASS | 0.008 | 0.020 | 0.000 | — | — |
| forward | FAIL | 0.015 | 0.058 | 0.438 | 4.600 | active_height |
| reverse | FAIL | 0.015 | 0.058 | 0.438 | 4.600 | active_height |
| left | FAIL | 0.054 | 0.165 | 0.369 | 4.600 | active_height |
| right | FAIL | 0.054 | 0.165 | 0.369 | 4.600 | active_height |
| forward-left | FAIL | 0.012 | 0.120 | 0.279 | 4.600 | active_height |
| forward-right | FAIL | 0.019 | 0.068 | 0.261 | 4.850 | active_height |
| reverse-left | FAIL | 0.019 | 0.068 | 0.261 | 4.850 | active_height |
| reverse-right | FAIL | 0.012 | 0.120 | 0.279 | 4.600 | active_height |
| turn-left | FAIL | 0.023 | 0.100 | 0.487 | 4.500 | active_height |
| turn-right | FAIL | 0.006 | 0.069 | 0.291 | 4.500 | active_height |
| climb-forward | FAIL | 0.019 | 0.040 | 0.186 | 5.400 | transient_height |
| descend-left | FAIL | 0.109 | 0.309 | 0.350 | 4.600 | transient_height |
| vertical-cycle | FAIL | 0.013 | 0.060 | 0.000 | — | transient_height |
| reverse-command | FAIL | 0.010 | 0.185 | 1.086 | 3.600 | active_height |
| brake | FAIL | 0.015 | 0.058 | 0.438 | 4.600 | active_height |
| slalom | FAIL | 0.026 | 0.122 | 0.388 | 4.500 | active_height, motion |
| gust | PASS | 0.040 | 0.145 | 0.324 | — | — |
| load-swing | PASS | 0.078 | 0.218 | 0.347 | — | — |
| recovery-diagonal | PASS | 0.023 | 0.099 | 0.438 | — | — |
| recovery-inverted | FAIL | 0.002 | 0.222 | 0.354 | — | transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/modular-24-fpv.pdf` et `traces/modular-24/fpv/`.
