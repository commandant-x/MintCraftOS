# modular-24 / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.010 | 0.037 | 0.000 | — | — |
| cold-hover | PASS | 0.015 | 0.046 | 0.000 | — | — |
| climb | FAIL | 0.018 | 0.037 | 0.000 | — | transient_height |
| descend | PASS | 0.003 | 0.033 | 0.000 | — | — |
| forward | FAIL | 0.062 | 0.481 | 1.803 | 5.550 | transient_height, active_height |
| reverse | FAIL | 0.126 | 0.654 | 1.621 | 5.550 | transient_height, active_height |
| left | FAIL | 0.095 | 0.152 | 0.996 | 5.700 | transient_height, active_height |
| right | FAIL | 0.053 | 0.570 | 1.517 | 5.650 | transient_height, active_height |
| forward-left | FAIL | 0.321 | 0.514 | 1.859 | 6.250 | transient_height, active_height, braking |
| forward-right | FAIL | 0.149 | 0.718 | 1.568 | 5.800 | transient_height, active_height |
| reverse-left | FAIL | 0.158 | 0.586 | 2.367 | 6.350 | transient_height, active_height, braking |
| reverse-right | FAIL | 0.080 | 0.831 | 1.720 | 6.350 | transient_height, active_height, braking |
| turn-left | FAIL | 0.165 | 0.224 | 1.037 | 2.200 | transient_height, active_attitude, active_height, motion |
| turn-right | FAIL | 0.270 | 0.678 | 1.360 | 2.250 | transient_height, active_attitude, active_height, motion |
| climb-forward | FAIL | 0.332 | 0.449 | 0.926 | 6.150 | transient_height, braking |
| descend-left | FAIL | 0.001 | 0.484 | 1.192 | 4.500 | transient_height |
| vertical-cycle | FAIL | 0.003 | 0.051 | 0.000 | — | transient_height |
| reverse-command | FAIL | 0.271 | 0.472 | 1.675 | 3.850 | transient_height, active_height |
| brake | FAIL | 0.062 | 0.481 | 1.803 | 5.550 | transient_height, active_height |
| slalom | FAIL | 0.212 | 0.444 | 1.700 | 4.950 | final_speed, transient_height, active_attitude, active_height, motion |
| gust | PASS | 0.045 | 0.371 | 1.458 | — | — |
| load-swing | PASS | 0.140 | 0.205 | 0.927 | — | — |
| recovery-diagonal | PASS | 0.050 | 0.594 | 0.857 | — | — |
| recovery-inverted | FAIL | 0.467 | 0.876 | 1.616 | — | tail_height_rms, transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/modular-24-fpv.pdf` et `traces/modular-24/fpv/`.
