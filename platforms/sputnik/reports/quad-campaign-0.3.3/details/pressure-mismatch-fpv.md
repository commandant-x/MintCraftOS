# pressure-mismatch / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.003 | 0.010 | 0.000 | — | — |
| cold-hover | PASS | 0.003 | 0.009 | 0.000 | — | — |
| climb | FAIL | 0.000 | 0.010 | 0.000 | — | transient_height |
| descend | PASS | 0.002 | 0.016 | 0.000 | — | — |
| forward | PASS | 0.008 | 0.038 | 0.273 | 4.700 | — |
| reverse | PASS | 0.008 | 0.038 | 0.273 | 4.700 | — |
| left | PASS | 0.009 | 0.038 | 0.307 | 4.750 | — |
| right | PASS | 0.009 | 0.038 | 0.307 | 4.750 | — |
| forward-left | PASS | 0.002 | 0.074 | 0.277 | 4.650 | — |
| forward-right | PASS | 0.010 | 0.042 | 0.304 | 4.750 | — |
| reverse-left | PASS | 0.010 | 0.042 | 0.304 | 4.750 | — |
| reverse-right | PASS | 0.002 | 0.074 | 0.277 | 4.650 | — |
| turn-left | PASS | 0.008 | 0.020 | 0.147 | 4.450 | — |
| turn-right | PASS | 0.009 | 0.029 | 0.199 | 4.450 | — |
| climb-forward | FAIL | 0.001 | 0.011 | 0.145 | 5.150 | transient_height |
| descend-left | FAIL | 0.024 | 0.040 | 0.288 | 4.700 | transient_height |
| vertical-cycle | FAIL | 0.001 | 0.011 | 0.000 | — | transient_height |
| reverse-command | PASS | 0.022 | 0.093 | 0.296 | 3.900 | — |
| brake | PASS | 0.008 | 0.038 | 0.273 | 4.700 | — |
| slalom | FAIL | 0.008 | 0.014 | 0.288 | 4.550 | motion |
| gust | PASS | 0.022 | 0.064 | 0.317 | — | — |
| load-swing | PASS | 0.002 | 0.029 | 0.141 | — | — |
| recovery-diagonal | PASS | 0.007 | 0.044 | 0.252 | — | — |
| recovery-inverted | PASS | 0.007 | 0.022 | 0.290 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/pressure-mismatch-fpv.pdf` et `traces/pressure-mismatch/fpv/`.
