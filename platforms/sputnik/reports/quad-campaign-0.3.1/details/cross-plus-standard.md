# cross-plus / standard

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.003 | 0.007 | 0.000 | — | — |
| cold-hover | PASS | 0.001 | 0.007 | 0.000 | — | — |
| climb | FAIL | 0.002 | 0.011 | 0.000 | — | transient_height |
| descend | FAIL | 0.007 | 0.020 | 0.000 | — | transient_height |
| forward | FAIL | 0.008 | 0.047 | 0.452 | 7.150 | transient_height, active_height, braking |
| reverse | FAIL | 0.010 | 0.025 | 0.256 | 5.350 | transient_height, active_height |
| left | FAIL | 0.010 | 0.031 | 0.225 | 5.400 | transient_height, active_height |
| right | FAIL | 0.007 | 0.017 | 0.266 | 5.400 | transient_height, active_height |
| forward-left | FAIL | 0.046 | 0.098 | 0.384 | 6.200 | transient_height, active_height, braking |
| forward-right | FAIL | 0.043 | 0.099 | 0.661 | 7.000 | transient_height, active_height, braking |
| reverse-left | FAIL | 0.012 | 0.096 | 0.451 | 6.150 | transient_height, active_height, braking |
| reverse-right | FAIL | 0.013 | 0.044 | 0.551 | 6.250 | transient_height, active_height, braking |
| turn-left | FAIL | 0.006 | 0.111 | 0.402 | 4.800 | active_attitude, active_height |
| turn-right | FAIL | 0.023 | 0.072 | 0.375 | 4.900 | active_attitude, active_height |
| climb-forward | FAIL | 0.014 | 0.019 | 0.248 | 6.050 | transient_height, active_vertical_rate, braking |
| descend-left | FAIL | 0.037 | 0.100 | 0.459 | 5.950 | transient_height, active_attitude, active_vertical_rate |
| vertical-cycle | FAIL | 0.028 | 0.047 | 0.000 | — | transient_height |
| reverse-command | FAIL | 0.006 | 0.037 | 0.304 | 3.700 | transient_height, active_height |
| brake | FAIL | 0.008 | 0.047 | 0.452 | 7.150 | transient_height, active_height, braking |
| slalom | FAIL | 0.000 | 0.078 | 0.434 | 4.750 | active_attitude, active_height, motion |
| gust | PASS | 0.002 | 0.059 | 0.365 | — | — |
| load-swing | FAIL | 0.598 | 0.068 | 0.457 | — | tail_height_rms |
| recovery-diagonal | PASS | 0.000 | 0.048 | 0.507 | — | — |
| recovery-inverted | FAIL | 0.004 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/cross-plus-standard.pdf` et `traces/cross-plus/standard/`.
