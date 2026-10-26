# square-x / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.020 | 0.000 | — | — |
| cold-hover | PASS | 0.011 | 0.020 | 0.000 | — | — |
| climb | FAIL | 0.005 | 0.022 | 0.000 | — | transient_height |
| descend | PASS | 0.010 | 0.050 | 0.000 | — | — |
| forward | FAIL | 0.013 | 0.188 | 1.277 | 4.750 | transient_height |
| reverse | FAIL | 0.034 | 0.158 | 0.656 | 4.650 | transient_height |
| left | FAIL | 0.091 | 0.200 | 0.588 | 4.650 | transient_height |
| right | FAIL | 0.006 | 0.193 | 0.257 | 4.700 | transient_height |
| forward-left | FAIL | 0.011 | 0.162 | 1.000 | 4.500 | transient_height |
| forward-right | FAIL | 0.040 | 0.055 | 0.253 | 4.500 | transient_height |
| reverse-left | FAIL | 0.008 | 0.123 | 1.198 | 4.500 | transient_height |
| reverse-right | FAIL | 0.094 | 0.190 | 0.489 | 4.550 | transient_height |
| turn-left | FAIL | 0.029 | 0.132 | 1.455 | 2.700 | transient_height, active_attitude, active_height |
| turn-right | FAIL | 0.027 | 0.108 | 0.731 | 2.500 | transient_height, active_attitude, active_height |
| climb-forward | FAIL | 0.062 | 0.147 | 0.548 | 5.650 | transient_height |
| descend-left | PASS | 0.046 | 0.119 | 0.635 | 4.300 | — |
| vertical-cycle | FAIL | 0.012 | 0.017 | 0.000 | — | transient_height |
| reverse-command | FAIL | 0.108 | 0.228 | 0.935 | 3.850 | transient_height, active_height |
| brake | FAIL | 0.013 | 0.188 | 1.277 | 4.750 | transient_height |
| slalom | FAIL | 0.053 | 0.252 | 1.192 | 3.300 | active_attitude, active_height, motion |
| gust | PASS | 0.007 | 0.023 | 0.007 | — | — |
| load-swing | PASS | 0.012 | 0.211 | 0.644 | — | — |
| recovery-diagonal | PASS | 0.005 | 0.152 | 0.712 | — | — |
| recovery-inverted | PASS | 0.012 | 0.188 | 1.083 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/square-x-fpv.pdf` et `traces/square-x/fpv/`.
