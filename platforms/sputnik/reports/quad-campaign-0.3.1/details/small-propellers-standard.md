# small-propellers / standard

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.000 | 0.001 | 0.000 | — | — |
| cold-hover | PASS | 0.000 | 0.002 | 0.000 | — | — |
| climb | FAIL | 0.005 | 0.014 | 0.000 | — | transient_height |
| descend | FAIL | 0.007 | 0.013 | 0.000 | — | transient_height |
| forward | PASS | 0.002 | 0.011 | 0.094 | 5.300 | — |
| reverse | PASS | 0.002 | 0.011 | 0.150 | 5.300 | — |
| left | PASS | 0.002 | 0.010 | 0.152 | 5.400 | — |
| right | PASS | 0.001 | 0.009 | 0.112 | 5.400 | — |
| forward-left | PASS | 0.001 | 0.006 | 0.102 | 5.300 | — |
| forward-right | PASS | 0.004 | 0.012 | 0.169 | 5.300 | — |
| reverse-left | PASS | 0.004 | 0.007 | 0.091 | 5.350 | — |
| reverse-right | PASS | 0.001 | 0.009 | 0.128 | 5.350 | — |
| turn-left | FAIL | 0.001 | 0.007 | 0.126 | 3.550 | active_attitude, motion |
| turn-right | FAIL | 0.001 | 0.005 | 0.104 | 3.550 | active_attitude, motion |
| climb-forward | FAIL | 0.006 | 0.013 | 0.082 | 5.800 | transient_height |
| descend-left | FAIL | 0.006 | 0.015 | 0.126 | 4.500 | transient_height |
| vertical-cycle | FAIL | 0.021 | 0.045 | 0.000 | — | transient_height |
| reverse-command | PASS | 0.001 | 0.010 | 0.139 | 4.350 | — |
| brake | PASS | 0.002 | 0.011 | 0.094 | 5.300 | — |
| slalom | FAIL | 0.002 | 0.011 | 0.128 | 4.650 | active_attitude, motion |
| gust | PASS | 0.001 | 0.009 | 0.153 | — | — |
| load-swing | FAIL | 0.563 | 0.007 | 0.094 | — | tail_height_rms |
| recovery-diagonal | PASS | 0.001 | 0.004 | 0.104 | — | — |
| recovery-inverted | FAIL | 0.000 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/small-propellers-standard.pdf` et `traces/small-propellers/standard/`.
