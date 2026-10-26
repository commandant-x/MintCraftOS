# mixed-propellers / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.054 | 0.154 | 0.893 | — | — |
| cold-hover | PASS | 0.010 | 0.084 | 0.509 | — | — |
| climb | PASS | 0.030 | 0.185 | 0.534 | — | — |
| descend | FAIL | 0.028 | 0.186 | 0.907 | — | active_attitude |
| forward | PASS | 0.025 | 0.126 | 0.460 | 4.400 | — |
| reverse | PASS | 0.032 | 0.111 | 0.458 | 4.550 | — |
| left | PASS | 0.040 | 0.148 | 0.575 | 5.150 | — |
| right | PASS | 0.042 | 0.088 | 0.803 | 5.000 | — |
| forward-left | PASS | 0.013 | 0.132 | 0.772 | 4.400 | — |
| forward-right | PASS | 0.026 | 0.166 | 0.844 | 4.400 | — |
| reverse-left | PASS | 0.054 | 0.128 | 0.582 | 5.700 | — |
| reverse-right | PASS | 0.054 | 0.136 | 0.557 | 5.150 | — |
| turn-left | PASS | 0.032 | 0.129 | 0.490 | 4.150 | — |
| turn-right | PASS | 0.009 | 0.143 | 0.705 | 3.850 | — |
| climb-forward | FAIL | 0.015 | 0.098 | 1.013 | 5.050 | transient_height |
| descend-left | PASS | 0.042 | 0.157 | 0.836 | 4.300 | — |
| vertical-cycle | FAIL | 0.042 | 0.157 | 0.651 | — | transient_height, active_attitude |
| reverse-command | PASS | 0.045 | 0.145 | 0.699 | 3.550 | — |
| brake | PASS | 0.025 | 0.126 | 0.460 | 4.400 | — |
| slalom | FAIL | 0.025 | 0.158 | 0.510 | 4.150 | active_attitude, motion |
| gust | PASS | 0.037 | 0.151 | 0.761 | — | — |
| load-swing | PASS | 0.026 | 0.100 | 1.592 | — | — |
| recovery-diagonal | PASS | 0.020 | 0.151 | 0.420 | — | — |
| recovery-inverted | FAIL | 0.019 | 0.162 | 0.575 | — | transient_height |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/mixed-propellers-fpv.pdf` et `traces/mixed-propellers/fpv/`.
