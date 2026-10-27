# telemetry-delay / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.014 | 0.020 | 0.261 | — | — |
| cold-hover | PASS | 0.006 | 0.049 | 0.501 | — | — |
| climb | FAIL | 0.002 | 0.032 | 0.375 | — | transient_height |
| descend | PASS | 0.002 | 0.026 | 0.163 | — | — |
| forward | PASS | 0.013 | 0.064 | 0.390 | 5.800 | — |
| reverse | FAIL | 0.061 | 0.221 | 7.496 | 9.450 | tail_tilt, tail_speed_rms, final_speed, braking |
| left | FAIL | 0.009 | 0.236 | 10.333 | 11.350 | tail_tilt, tail_speed_rms, braking |
| right | FAIL | 0.018 | 0.264 | 10.748 | 31.800 | tail_tilt, tail_speed_rms, final_speed, braking |
| forward-left | PASS | 0.006 | 0.018 | 0.302 | 4.100 | — |
| forward-right | PASS | 0.012 | 0.039 | 0.521 | 5.050 | — |
| reverse-left | FAIL | 0.027 | 0.024 | 0.276 | 6.400 | braking |
| reverse-right | PASS | 0.011 | 0.037 | 0.446 | 5.200 | — |
| turn-left | PASS | 0.141 | 0.254 | 0.505 | 4.900 | — |
| turn-right | FAIL | 0.033 | 0.075 | 0.501 | 17.550 | braking |
| climb-forward | FAIL | 0.016 | 0.265 | 7.884 | 7.000 | tail_tilt, tail_speed_rms, final_speed, transient_height, braking |
| descend-left | FAIL | 0.011 | 0.077 | 0.458 | 3.800 | transient_height, active_attitude |
| vertical-cycle | FAIL | 0.001 | 0.011 | 0.000 | — | transient_height |
| reverse-command | FAIL | 0.036 | 0.342 | 7.557 | 5.650 | tail_tilt, tail_speed_rms, final_speed |
| brake | PASS | 0.013 | 0.064 | 0.390 | 5.800 | — |
| slalom | FAIL | 0.015 | 0.022 | 0.314 | 5.200 | motion |
| gust | PASS | 0.012 | 0.025 | 0.341 | — | — |
| load-swing | PASS | 0.018 | 0.035 | 0.338 | — | — |
| recovery-diagonal | PASS | 0.006 | 0.036 | 0.366 | — | — |
| recovery-inverted | FAIL | 0.070 | 0.073 | 0.369 | — | transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/telemetry-delay-fpv.pdf` et `traces/telemetry-delay/fpv/`.
