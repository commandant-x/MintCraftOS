# low-inertia / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.001 | 0.014 | 0.000 | — | — |
| cold-hover | PASS | 0.004 | 0.025 | 0.000 | — | — |
| climb | FAIL | 0.007 | 0.023 | 0.000 | — | transient_height |
| descend | PASS | 0.010 | 0.043 | 0.000 | — | — |
| forward | PASS | 0.056 | 0.221 | 1.349 | 4.450 | — |
| reverse | PASS | 0.006 | 0.059 | 0.135 | 4.500 | — |
| left | PASS | 0.002 | 0.030 | 0.149 | 4.450 | — |
| right | PASS | 0.002 | 0.030 | 0.149 | 4.450 | — |
| forward-left | PASS | 0.002 | 0.249 | 2.128 | 4.950 | — |
| forward-right | PASS | 0.002 | 0.249 | 2.128 | 4.950 | — |
| reverse-left | PASS | 0.023 | 0.147 | 0.298 | 4.450 | — |
| reverse-right | PASS | 0.002 | 0.249 | 2.128 | 4.950 | — |
| turn-left | FAIL | 0.011 | 0.025 | 0.026 | 5.950 | active_attitude |
| turn-right | FAIL | 0.006 | 0.033 | 0.172 | 5.800 | active_attitude |
| climb-forward | FAIL | 0.061 | 0.147 | 1.539 | 3.900 | transient_height, active_attitude |
| descend-left | PASS | 0.018 | 0.048 | 0.036 | 4.300 | — |
| vertical-cycle | FAIL | 0.004 | 0.023 | 0.000 | — | transient_height |
| reverse-command | FAIL | 0.048 | 0.172 | 2.185 | 4.700 | active_height |
| brake | PASS | 0.056 | 0.221 | 1.349 | 4.450 | — |
| slalom | FAIL | 0.023 | 0.115 | 1.359 | 4.250 | active_attitude, active_height |
| gust | PASS | 0.008 | 0.019 | 0.296 | — | — |
| load-swing | PASS | 0.091 | 0.222 | 1.404 | — | — |
| recovery-diagonal | PASS | 0.028 | 0.174 | 1.166 | — | — |
| recovery-inverted | FAIL | 80.390 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/low-inertia-fpv.pdf` et `traces/low-inertia/fpv/`.
