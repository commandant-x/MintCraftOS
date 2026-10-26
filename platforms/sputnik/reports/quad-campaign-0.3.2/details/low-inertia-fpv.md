# low-inertia / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.001 | 0.014 | 0.000 | — | — |
| cold-hover | PASS | 0.005 | 0.022 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.023 | 0.000 | — | — |
| descend | PASS | 0.000 | 0.044 | 0.000 | — | — |
| forward | PASS | 0.021 | 0.214 | 1.532 | 5.650 | — |
| reverse | PASS | 0.016 | 0.031 | 0.084 | 5.550 | — |
| left | PASS | 0.008 | 0.021 | 0.078 | 3.950 | — |
| right | PASS | 0.008 | 0.021 | 0.078 | 3.950 | — |
| forward-left | PASS | 0.003 | 0.024 | 0.062 | 5.550 | — |
| forward-right | PASS | 0.003 | 0.024 | 0.062 | 5.550 | — |
| reverse-left | PASS | 0.003 | 0.024 | 0.062 | 5.550 | — |
| reverse-right | PASS | 0.003 | 0.024 | 0.062 | 5.550 | — |
| turn-left | PASS | 0.029 | 0.323 | 1.527 | 5.250 | — |
| turn-right | PASS | 0.008 | 0.022 | 0.122 | 5.700 | — |
| climb-forward | PASS | 0.005 | 0.023 | 0.012 | 6.000 | — |
| descend-left | PASS | 0.006 | 0.050 | 0.021 | 6.000 | — |
| vertical-cycle | PASS | 0.005 | 0.020 | 0.000 | — | — |
| reverse-command | PASS | 0.012 | 0.027 | 0.091 | 5.850 | — |
| brake | PASS | 0.021 | 0.214 | 1.532 | 5.650 | — |
| slalom | FAIL | 0.008 | 0.023 | 0.171 | 5.400 | active_attitude, motion |
| gust | PASS | 0.007 | 0.028 | 0.023 | — | — |
| load-swing | PASS | 0.011 | 0.292 | 1.752 | — | — |
| recovery-diagonal | PASS | 0.002 | 0.020 | 0.066 | — | — |
| recovery-inverted | FAIL | 80.318 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/low-inertia-fpv.pdf` et `traces/low-inertia/fpv/`.
