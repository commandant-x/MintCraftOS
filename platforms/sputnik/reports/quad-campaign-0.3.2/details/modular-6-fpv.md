# modular-6 / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.026 | 0.045 | 0.000 | — | — |
| cold-hover | PASS | 0.015 | 0.049 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.012 | 0.000 | — | — |
| descend | PASS | 0.000 | 0.014 | 0.000 | — | — |
| forward | PASS | 0.013 | 0.042 | 0.032 | 4.450 | — |
| reverse | PASS | 0.013 | 0.042 | 0.032 | 4.450 | — |
| left | PASS | 0.001 | 0.092 | 0.299 | 4.350 | — |
| right | PASS | 0.001 | 0.092 | 0.299 | 4.350 | — |
| forward-left | PASS | 0.021 | 0.056 | 0.249 | 4.700 | — |
| forward-right | PASS | 0.021 | 0.056 | 0.249 | 4.700 | — |
| reverse-left | PASS | 0.021 | 0.056 | 0.249 | 4.700 | — |
| reverse-right | PASS | 0.021 | 0.056 | 0.249 | 4.700 | — |
| turn-left | PASS | 0.019 | 0.042 | 0.013 | 4.400 | — |
| turn-right | PASS | 0.019 | 0.042 | 0.013 | 4.400 | — |
| climb-forward | PASS | 0.008 | 0.057 | 0.192 | 5.200 | — |
| descend-left | PASS | 0.005 | 0.039 | 0.300 | 4.450 | — |
| vertical-cycle | PASS | 0.019 | 0.048 | 0.000 | — | — |
| reverse-command | PASS | 0.018 | 0.054 | 0.323 | 3.950 | — |
| brake | PASS | 0.013 | 0.042 | 0.032 | 4.450 | — |
| slalom | PASS | 0.013 | 0.069 | 0.319 | 4.500 | — |
| gust | PASS | 0.045 | 0.056 | 0.146 | — | — |
| load-swing | PASS | 0.002 | 0.035 | 0.284 | — | — |
| recovery-diagonal | PASS | 0.012 | 0.079 | 0.309 | — | — |
| recovery-inverted | FAIL | 0.071 | 0.105 | 0.379 | — | transient_height |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/modular-6-fpv.pdf` et `traces/modular-6/fpv/`.
