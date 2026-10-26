# reference / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.004 | 0.025 | 0.000 | — | — |
| cold-hover | PASS | 0.006 | 0.018 | 0.000 | — | — |
| climb | FAIL | 0.007 | 0.023 | 0.000 | — | transient_height |
| descend | PASS | 0.010 | 0.043 | 0.000 | — | — |
| forward | PASS | 0.015 | 0.155 | 0.431 | 4.700 | — |
| reverse | PASS | 0.016 | 0.056 | 0.052 | 4.600 | — |
| left | FAIL | 0.067 | 0.206 | 0.901 | 6.400 | transient_height, active_height, braking |
| right | FAIL | 0.035 | 0.030 | 0.490 | 6.150 | transient_height, braking |
| forward-left | FAIL | 0.096 | 0.201 | 0.986 | 4.900 | transient_height |
| forward-right | FAIL | 0.049 | 0.228 | 0.661 | 5.000 | transient_height |
| reverse-left | FAIL | 0.082 | 0.162 | 0.530 | 4.900 | transient_height |
| reverse-right | FAIL | 0.023 | 0.177 | 1.254 | 5.000 | transient_height |
| turn-left | FAIL | 0.061 | 0.109 | 0.486 | 3.800 | transient_height, active_attitude, active_height |
| turn-right | FAIL | 0.125 | 0.169 | 0.849 | 5.250 | transient_height, active_attitude, active_height, motion |
| climb-forward | FAIL | 0.029 | 0.107 | 0.158 | 4.800 | transient_height |
| descend-left | PASS | 0.036 | 0.199 | 0.608 | 4.300 | — |
| vertical-cycle | FAIL | 0.005 | 0.016 | 0.000 | — | transient_height |
| reverse-command | FAIL | 0.016 | 0.107 | 0.664 | 3.700 | active_height |
| brake | PASS | 0.015 | 0.155 | 0.431 | 4.700 | — |
| slalom | FAIL | 0.123 | 0.136 | 0.497 | 4.300 | transient_height, active_attitude, active_height, motion |
| gust | PASS | 0.021 | 0.141 | 0.436 | — | — |
| load-swing | PASS | 0.003 | 0.371 | 0.843 | — | — |
| recovery-diagonal | PASS | 0.022 | 0.232 | 0.788 | — | — |
| recovery-inverted | PASS | 0.006 | 0.160 | 0.835 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/reference-fpv.pdf` et `traces/reference/fpv/`.
