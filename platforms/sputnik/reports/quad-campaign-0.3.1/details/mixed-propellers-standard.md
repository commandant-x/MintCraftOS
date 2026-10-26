# mixed-propellers / standard

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.009 | 0.229 | 0.933 | — | — |
| cold-hover | PASS | 0.075 | 0.197 | 0.607 | — | — |
| climb | FAIL | 0.073 | 0.299 | 0.555 | — | transient_height, active_vertical_rate |
| descend | FAIL | 0.027 | 0.197 | 0.494 | — | transient_height |
| forward | FAIL | 0.041 | 0.171 | 0.814 | 8.150 | transient_height, active_height, braking |
| reverse | FAIL | 0.032 | 0.183 | 0.757 | 9.100 | transient_height, active_height, braking |
| left | FAIL | 0.010 | 0.271 | 0.628 | 6.050 | transient_height, active_height, braking |
| right | FAIL | 0.003 | 0.398 | 0.824 | 8.350 | transient_height, active_height, braking |
| forward-left | FAIL | 0.011 | 0.081 | 0.491 | 10.100 | transient_height, active_height, braking |
| forward-right | FAIL | 0.029 | 0.125 | 0.598 | 6.750 | transient_height, active_height, braking |
| reverse-left | FAIL | 0.011 | 0.131 | 0.529 | 8.450 | transient_height, active_height, braking |
| reverse-right | FAIL | 0.055 | 0.309 | 0.843 | 8.500 | transient_height, active_height, braking |
| turn-left | FAIL | 0.004 | 0.259 | 0.408 | 4.350 | transient_height, active_attitude, active_height, motion |
| turn-right | FAIL | 0.061 | 0.243 | 0.960 | 2.950 | transient_height, active_attitude, active_height |
| climb-forward | FAIL | 0.088 | 0.450 | 0.922 | 6.450 | transient_height, active_vertical_rate, braking |
| descend-left | FAIL | 0.112 | 0.240 | 0.796 | 9.300 | transient_height, active_attitude, braking |
| vertical-cycle | FAIL | 0.034 | 0.221 | 0.435 | — | transient_height |
| reverse-command | FAIL | 0.034 | 0.166 | 0.886 | 4.150 | transient_height, active_attitude, active_height, motion |
| brake | FAIL | 0.041 | 0.171 | 0.814 | 8.150 | transient_height, active_height, braking |
| slalom | FAIL | 0.054 | 0.244 | 0.598 | 5.000 | active_attitude, active_height, motion |
| gust | PASS | 0.018 | 0.229 | 0.939 | — | — |
| load-swing | FAIL | 0.639 | 0.345 | 1.295 | — | tail_height_rms |
| recovery-diagonal | PASS | 0.068 | 0.139 | 0.683 | — | — |
| recovery-inverted | FAIL | 0.037 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/mixed-propellers-standard.pdf` et `traces/mixed-propellers/standard/`.
