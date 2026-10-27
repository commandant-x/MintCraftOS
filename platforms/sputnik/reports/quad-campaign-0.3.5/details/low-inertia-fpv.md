# low-inertia / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.008 | 0.000 | — | — |
| cold-hover | PASS | 0.001 | 0.007 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.011 | 0.000 | — | — |
| descend | PASS | 0.001 | 0.010 | 0.000 | — | — |
| forward | PASS | 0.030 | 0.095 | 0.440 | 5.750 | — |
| reverse | PASS | 0.030 | 0.075 | 0.689 | 5.850 | — |
| left | PASS | 0.060 | 0.121 | 0.578 | 4.550 | — |
| right | PASS | 0.060 | 0.121 | 0.578 | 4.550 | — |
| forward-left | PASS | 0.035 | 0.123 | 0.638 | 4.950 | — |
| forward-right | PASS | 0.030 | 0.091 | 0.749 | 5.150 | — |
| reverse-left | PASS | 0.030 | 0.091 | 0.749 | 5.150 | — |
| reverse-right | PASS | 0.035 | 0.123 | 0.638 | 4.950 | — |
| turn-left | PASS | 0.024 | 0.097 | 0.368 | 3.900 | — |
| turn-right | PASS | 0.004 | 0.070 | 0.633 | 3.900 | — |
| climb-forward | PASS | 0.021 | 0.096 | 0.634 | 5.500 | — |
| descend-left | PASS | 0.059 | 0.094 | 1.079 | 5.500 | — |
| vertical-cycle | PASS | 0.002 | 0.009 | 0.000 | — | — |
| reverse-command | PASS | 0.036 | 0.092 | 0.538 | 5.500 | — |
| brake | PASS | 0.030 | 0.095 | 0.440 | 5.750 | — |
| slalom | FAIL | 0.020 | 0.084 | 0.725 | 5.650 | active_attitude, motion |
| gust | PASS | 0.003 | 0.104 | 0.769 | — | — |
| load-swing | PASS | 0.006 | 0.041 | 0.383 | — | — |
| recovery-diagonal | PASS | 0.032 | 0.117 | 0.867 | — | — |
| recovery-inverted | FAIL | 80.233 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/low-inertia-fpv.pdf` et `traces/low-inertia/fpv/`.
