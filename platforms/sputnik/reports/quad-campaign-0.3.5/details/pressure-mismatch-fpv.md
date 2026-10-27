# pressure-mismatch / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.005 | 0.006 | 0.000 | — | — |
| cold-hover | PASS | 0.004 | 0.007 | 0.000 | — | — |
| climb | PASS | 0.001 | 0.008 | 0.000 | — | — |
| descend | PASS | 0.003 | 0.010 | 0.000 | — | — |
| forward | PASS | 0.024 | 0.039 | 0.364 | 4.700 | — |
| reverse | PASS | 0.024 | 0.039 | 0.364 | 4.700 | — |
| left | PASS | 0.018 | 0.035 | 0.283 | 4.650 | — |
| right | PASS | 0.018 | 0.035 | 0.283 | 4.650 | — |
| forward-left | PASS | 0.019 | 0.026 | 0.273 | 4.750 | — |
| forward-right | PASS | 0.018 | 0.039 | 0.383 | 4.750 | — |
| reverse-left | PASS | 0.018 | 0.039 | 0.383 | 4.750 | — |
| reverse-right | PASS | 0.019 | 0.026 | 0.273 | 4.750 | — |
| turn-left | PASS | 0.011 | 0.030 | 0.296 | 4.400 | — |
| turn-right | PASS | 0.017 | 0.045 | 0.385 | 4.450 | — |
| climb-forward | PASS | 0.004 | 0.018 | 0.219 | 5.350 | — |
| descend-left | PASS | 0.014 | 0.025 | 0.278 | 4.400 | — |
| vertical-cycle | PASS | 0.003 | 0.008 | 0.000 | — | — |
| reverse-command | PASS | 0.013 | 0.064 | 0.357 | 4.150 | — |
| brake | PASS | 0.024 | 0.039 | 0.364 | 4.700 | — |
| slalom | FAIL | 0.015 | 0.035 | 0.334 | 4.550 | motion |
| gust | PASS | 0.003 | 0.047 | 0.261 | — | — |
| load-swing | PASS | 0.007 | 0.014 | 0.166 | — | — |
| recovery-diagonal | PASS | 0.008 | 0.036 | 0.260 | — | — |
| recovery-inverted | PASS | 0.033 | 0.065 | 0.379 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/pressure-mismatch-fpv.pdf` et `traces/pressure-mismatch/fpv/`.
