# cross-plus / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.011 | 0.021 | 0.000 | — | — |
| cold-hover | PASS | 0.000 | 0.020 | 0.000 | — | — |
| climb | FAIL | 0.004 | 0.023 | 0.000 | — | transient_height |
| descend | PASS | 0.013 | 0.047 | 0.000 | — | — |
| forward | PASS | 0.000 | 0.072 | 0.547 | 4.450 | — |
| reverse | PASS | 0.002 | 0.043 | 0.062 | 4.500 | — |
| left | PASS | 0.002 | 0.122 | 1.004 | 4.450 | — |
| right | PASS | 0.025 | 0.171 | 0.756 | 4.450 | — |
| forward-left | FAIL | 0.033 | 0.197 | 1.215 | 4.800 | transient_height |
| forward-right | FAIL | 0.009 | 0.041 | 0.025 | 4.750 | transient_height |
| reverse-left | FAIL | 0.061 | 0.117 | 0.872 | 4.800 | transient_height |
| reverse-right | FAIL | 0.007 | 0.084 | 0.222 | 4.800 | transient_height |
| turn-left | FAIL | 0.050 | 0.125 | 0.591 | 3.200 | transient_height, active_attitude, active_height, motion |
| turn-right | FAIL | 0.024 | 0.217 | 1.015 | 5.200 | transient_height, active_attitude, active_height, motion |
| climb-forward | FAIL | 0.006 | 0.092 | 0.352 | 4.750 | transient_height |
| descend-left | PASS | 0.054 | 0.085 | 0.819 | 4.200 | — |
| vertical-cycle | FAIL | 0.002 | 0.020 | 0.000 | — | transient_height |
| reverse-command | PASS | 0.009 | 0.029 | 0.014 | 3.900 | — |
| brake | PASS | 0.000 | 0.072 | 0.547 | 4.450 | — |
| slalom | FAIL | 0.032 | 0.177 | 1.025 | 5.250 | transient_height, active_attitude, active_height |
| gust | PASS | 0.004 | 0.028 | 0.032 | — | — |
| load-swing | PASS | 0.017 | 0.179 | 0.504 | — | — |
| recovery-diagonal | PASS | 0.020 | 0.183 | 0.826 | — | — |
| recovery-inverted | PASS | 0.019 | 0.024 | 0.172 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/cross-plus-fpv.pdf` et `traces/cross-plus/fpv/`.
