# telemetry-delay / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.014 | 0.020 | 0.261 | — | — |
| cold-hover | PASS | 0.004 | 0.021 | 0.348 | — | — |
| climb | FAIL | 0.002 | 0.032 | 0.375 | — | transient_height |
| descend | PASS | 0.002 | 0.026 | 0.163 | — | — |
| forward | FAIL | 0.004 | 0.344 | 7.663 | 4.350 | tail_tilt, tail_speed_rms, final_speed |
| reverse | FAIL | 0.099 | 0.251 | 7.452 | 4.450 | tail_tilt, tail_speed_rms, final_speed |
| left | FAIL | 0.031 | 0.241 | 10.615 | 8.650 | tail_tilt, tail_speed_rms, final_speed, braking |
| right | FAIL | 0.021 | 0.304 | 9.854 | 46.700 | tail_tilt, tail_speed_rms, final_speed, braking |
| forward-left | PASS | 0.002 | 0.041 | 0.335 | 5.050 | — |
| forward-right | PASS | 0.048 | 0.062 | 0.519 | 5.200 | — |
| reverse-left | PASS | 0.002 | 0.023 | 0.289 | 4.950 | — |
| reverse-right | PASS | 0.014 | 0.024 | 0.286 | 5.100 | — |
| turn-left | PASS | 0.028 | 0.053 | 0.413 | 5.600 | — |
| turn-right | FAIL | 0.043 | 0.061 | 0.388 | 6.800 | braking |
| climb-forward | FAIL | 0.071 | 0.463 | 8.445 | 6.450 | tail_tilt, tail_speed_rms, transient_height, braking |
| descend-left | FAIL | 0.012 | 0.073 | 0.535 | 3.850 | transient_height, active_attitude |
| vertical-cycle | FAIL | 0.001 | 0.011 | 0.000 | — | transient_height |
| reverse-command | PASS | 0.013 | 0.042 | 0.474 | 4.500 | — |
| brake | FAIL | 0.004 | 0.344 | 7.663 | 4.350 | tail_tilt, tail_speed_rms, final_speed |
| slalom | FAIL | 0.013 | 0.046 | 0.378 | 7.750 | motion, braking |
| gust | PASS | 0.023 | 0.049 | 0.437 | — | — |
| load-swing | FAIL | 0.301 | 1.891 | 22.848 | — | tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed |
| recovery-diagonal | PASS | 0.000 | 0.030 | 0.375 | — | — |
| recovery-inverted | FAIL | 0.027 | 0.058 | 0.504 | — | transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/telemetry-delay-fpv.pdf` et `traces/telemetry-delay/fpv/`.
