# weak-one-rotor / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.017 | 0.062 | 0.406 | — | — |
| cold-hover | PASS | 0.001 | 0.098 | 0.389 | — | — |
| climb | FAIL | 0.013 | 0.044 | 0.399 | — | transient_height, active_attitude |
| descend | FAIL | 0.060 | 0.218 | 1.011 | — | active_attitude, active_vertical_rate |
| forward | FAIL | 0.011 | 0.251 | 0.554 | 9.750 | transient_height, active_height, braking |
| reverse | FAIL | 0.012 | 0.099 | 0.399 | 4.950 | transient_height, active_attitude |
| left | FAIL | 0.036 | 0.084 | 0.383 | 7.650 | braking |
| right | FAIL | 0.057 | 0.090 | 0.305 | 11.250 | transient_height, active_attitude, braking |
| forward-left | FAIL | 0.009 | 0.107 | 0.548 | 10.250 | transient_height, active_attitude, active_height, braking |
| forward-right | FAIL | 0.057 | 0.122 | 0.520 | 10.850 | transient_height, active_attitude, braking |
| reverse-left | FAIL | 0.020 | 0.070 | 0.512 | 9.950 | transient_height, braking |
| reverse-right | FAIL | 0.015 | 0.106 | 0.516 | 2.850 | transient_height, active_attitude |
| turn-left | FAIL | 0.044 | 0.114 | 0.878 | 6.000 | transient_height, active_attitude, active_height |
| turn-right | FAIL | 0.043 | 0.111 | 0.363 | 3.000 | transient_height, active_attitude, active_height |
| climb-forward | FAIL | 0.030 | 0.065 | 0.426 | 9.850 | transient_height, braking |
| descend-left | FAIL | 0.016 | 0.233 | 1.405 | 9.000 | active_attitude, braking |
| vertical-cycle | FAIL | 0.035 | 0.099 | 0.626 | — | transient_height, active_attitude, active_vertical_rate |
| reverse-command | FAIL | 0.065 | 0.200 | 0.627 | 10.950 | transient_height, active_height, braking |
| brake | FAIL | 0.011 | 0.251 | 0.554 | 9.750 | transient_height, active_height, braking |
| slalom | FAIL | 0.013 | 0.117 | 0.524 | 15.250 | transient_height, active_attitude, active_height, motion, braking |
| gust | PASS | 0.007 | 0.108 | 0.495 | — | — |
| load-swing | PASS | 0.045 | 0.064 | 0.288 | — | — |
| recovery-diagonal | PASS | 0.016 | 0.069 | 0.523 | — | — |
| recovery-inverted | PASS | 0.019 | 0.115 | 0.855 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/weak-one-rotor-fpv.pdf` et `traces/weak-one-rotor/fpv/`.
