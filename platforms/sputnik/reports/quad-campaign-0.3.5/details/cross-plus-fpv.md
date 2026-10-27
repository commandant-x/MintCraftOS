# cross-plus / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.008 | 0.000 | — | — |
| cold-hover | PASS | 0.001 | 0.007 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.011 | 0.000 | — | — |
| descend | PASS | 0.001 | 0.010 | 0.000 | — | — |
| forward | PASS | 0.001 | 0.020 | 0.297 | 4.400 | — |
| reverse | PASS | 0.001 | 0.020 | 0.297 | 4.400 | — |
| left | PASS | 0.002 | 0.012 | 0.181 | 4.400 | — |
| right | PASS | 0.002 | 0.012 | 0.181 | 4.400 | — |
| forward-left | PASS | 0.010 | 0.045 | 0.265 | 4.750 | — |
| forward-right | PASS | 0.010 | 0.045 | 0.265 | 4.750 | — |
| reverse-left | PASS | 0.010 | 0.045 | 0.265 | 4.750 | — |
| reverse-right | PASS | 0.010 | 0.045 | 0.265 | 4.750 | — |
| turn-left | PASS | 0.009 | 0.013 | 0.254 | 4.500 | — |
| turn-right | PASS | 0.009 | 0.013 | 0.254 | 4.500 | — |
| climb-forward | PASS | 0.007 | 0.015 | 0.311 | 5.150 | — |
| descend-left | PASS | 0.019 | 0.033 | 0.278 | 4.200 | — |
| vertical-cycle | PASS | 0.002 | 0.009 | 0.000 | — | — |
| reverse-command | PASS | 0.003 | 0.019 | 0.266 | 3.900 | — |
| brake | PASS | 0.001 | 0.020 | 0.297 | 4.400 | — |
| slalom | FAIL | 0.003 | 0.025 | 0.296 | 4.550 | motion |
| gust | PASS | 0.010 | 0.016 | 0.283 | — | — |
| load-swing | PASS | 0.018 | 0.022 | 0.177 | — | — |
| recovery-diagonal | PASS | 0.014 | 0.035 | 0.248 | — | — |
| recovery-inverted | PASS | 0.009 | 0.012 | 0.207 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/cross-plus-fpv.pdf` et `traces/cross-plus/fpv/`.
