# modular-24 / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.013 | 0.055 | 0.000 | — | — |
| cold-hover | PASS | 0.003 | 0.045 | 0.000 | — | — |
| climb | FAIL | 0.002 | 0.016 | 0.000 | — | transient_height |
| descend | PASS | 0.008 | 0.020 | 0.000 | — | — |
| forward | FAIL | 0.074 | 0.081 | 0.402 | 4.700 | active_height |
| reverse | FAIL | 0.074 | 0.081 | 0.402 | 4.700 | active_height |
| left | FAIL | 0.022 | 0.050 | 0.532 | 4.600 | active_height |
| right | FAIL | 0.022 | 0.050 | 0.532 | 4.600 | active_height |
| forward-left | FAIL | 0.037 | 0.117 | 0.316 | 4.750 | active_height |
| forward-right | FAIL | 0.027 | 0.083 | 0.309 | 4.700 | active_height |
| reverse-left | FAIL | 0.027 | 0.083 | 0.309 | 4.700 | active_height |
| reverse-right | FAIL | 0.037 | 0.117 | 0.316 | 4.750 | active_height |
| turn-left | FAIL | 0.023 | 0.049 | 0.489 | 4.500 | active_height |
| turn-right | FAIL | 0.018 | 0.098 | 0.229 | 4.450 | active_height |
| climb-forward | FAIL | 0.008 | 0.082 | 0.317 | 4.700 | transient_height |
| descend-left | FAIL | 0.020 | 0.093 | 0.402 | 4.550 | transient_height |
| vertical-cycle | FAIL | 0.013 | 0.060 | 0.000 | — | transient_height |
| reverse-command | FAIL | 0.023 | 0.267 | 0.417 | 4.050 | active_height |
| brake | FAIL | 0.074 | 0.081 | 0.402 | 4.700 | active_height |
| slalom | FAIL | 0.062 | 0.179 | 0.356 | 4.500 | active_height, motion |
| gust | PASS | 0.008 | 0.085 | 0.389 | — | — |
| load-swing | PASS | 0.020 | 0.028 | 0.276 | — | — |
| recovery-diagonal | PASS | 0.002 | 0.070 | 0.373 | — | — |
| recovery-inverted | FAIL | 0.029 | 0.229 | 0.333 | — | transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/modular-24-fpv.pdf` et `traces/modular-24/fpv/`.
