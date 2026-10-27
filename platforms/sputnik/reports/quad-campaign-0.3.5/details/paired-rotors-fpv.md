# paired-rotors / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.004 | 0.023 | 0.000 | — | — |
| cold-hover | PASS | 0.005 | 0.018 | 0.000 | — | — |
| climb | FAIL | 0.007 | 0.015 | 0.000 | — | transient_height |
| descend | PASS | 0.019 | 0.044 | 0.000 | — | — |
| forward | FAIL | 0.046 | 0.129 | 0.323 | 4.600 | active_height |
| reverse | FAIL | 0.046 | 0.129 | 0.323 | 4.600 | active_height |
| left | FAIL | 0.047 | 0.111 | 0.379 | 4.700 | active_height |
| right | FAIL | 0.047 | 0.111 | 0.379 | 4.700 | active_height |
| forward-left | FAIL | 0.038 | 0.139 | 0.242 | 4.700 | active_height |
| forward-right | FAIL | 0.056 | 0.109 | 0.265 | 4.700 | active_height |
| reverse-left | FAIL | 0.056 | 0.109 | 0.265 | 4.700 | active_height |
| reverse-right | FAIL | 0.038 | 0.139 | 0.242 | 4.700 | active_height |
| turn-left | FAIL | 0.041 | 0.104 | 0.312 | 4.350 | active_height |
| turn-right | FAIL | 0.016 | 0.180 | 0.281 | 4.400 | active_height |
| climb-forward | PASS | 0.025 | 0.108 | 0.181 | 4.950 | — |
| descend-left | FAIL | 0.051 | 0.144 | 0.317 | 3.850 | transient_height |
| vertical-cycle | FAIL | 0.003 | 0.018 | 0.000 | — | transient_height |
| reverse-command | FAIL | 0.058 | 0.132 | 0.510 | 4.100 | active_height |
| brake | FAIL | 0.046 | 0.129 | 0.323 | 4.600 | active_height |
| slalom | FAIL | 0.070 | 0.122 | 0.325 | 4.400 | active_height, motion |
| gust | PASS | 0.011 | 0.116 | 0.327 | — | — |
| load-swing | PASS | 0.026 | 0.090 | 0.375 | — | — |
| recovery-diagonal | PASS | 0.071 | 0.148 | 0.312 | — | — |
| recovery-inverted | PASS | 0.038 | 0.155 | 0.260 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/paired-rotors-fpv.pdf` et `traces/paired-rotors/fpv/`.
