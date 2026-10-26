# low-inertia / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.008 | 0.000 | — | — |
| cold-hover | PASS | 0.002 | 0.007 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.011 | 0.000 | — | — |
| descend | PASS | 0.001 | 0.010 | 0.000 | — | — |
| forward | PASS | 0.039 | 0.111 | 0.626 | 5.550 | — |
| reverse | PASS | 0.044 | 0.107 | 0.608 | 5.650 | — |
| left | PASS | 0.013 | 0.071 | 0.590 | 4.450 | — |
| right | PASS | 0.013 | 0.071 | 0.590 | 4.450 | — |
| forward-left | PASS | 0.013 | 0.098 | 0.536 | 5.300 | — |
| forward-right | PASS | 0.021 | 0.124 | 0.918 | 5.450 | — |
| reverse-left | PASS | 0.021 | 0.124 | 0.918 | 5.450 | — |
| reverse-right | PASS | 0.013 | 0.098 | 0.536 | 5.300 | — |
| turn-left | PASS | 0.054 | 0.120 | 0.782 | 4.650 | — |
| turn-right | PASS | 0.024 | 0.107 | 0.506 | 4.850 | — |
| climb-forward | PASS | 0.008 | 0.094 | 0.671 | 5.850 | — |
| descend-left | PASS | 0.030 | 0.093 | 0.911 | 5.350 | — |
| vertical-cycle | PASS | 0.002 | 0.009 | 0.000 | — | — |
| reverse-command | PASS | 0.041 | 0.109 | 0.537 | 5.800 | — |
| brake | PASS | 0.039 | 0.111 | 0.626 | 5.550 | — |
| slalom | FAIL | 0.032 | 0.124 | 0.603 | 5.300 | active_attitude, motion |
| gust | PASS | 0.062 | 0.090 | 0.554 | — | — |
| load-swing | PASS | 0.007 | 0.147 | 0.570 | — | — |
| recovery-diagonal | PASS | 0.048 | 0.104 | 0.592 | — | — |
| recovery-inverted | FAIL | 80.233 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/low-inertia-fpv.pdf` et `traces/low-inertia/fpv/`.
