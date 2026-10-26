# telemetry-delay / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.006 | 0.026 | 0.000 | — | — |
| cold-hover | PASS | 0.001 | 0.023 | 0.000 | — | — |
| climb | FAIL | 0.009 | 0.194 | 1.137 | — | transient_height |
| descend | PASS | 0.012 | 0.055 | 0.000 | — | — |
| forward | PASS | 0.016 | 0.030 | 0.081 | 5.900 | — |
| reverse | PASS | 0.038 | 0.187 | 1.985 | 5.900 | — |
| left | PASS | 0.065 | 0.195 | 2.045 | 4.550 | — |
| right | FAIL | 0.042 | 0.274 | 1.388 | 6.150 | braking |
| forward-left | FAIL | 0.069 | 0.334 | 2.536 | 6.200 | braking |
| forward-right | FAIL | 0.153 | 0.247 | 0.857 | 6.150 | braking |
| reverse-left | PASS | 0.095 | 0.280 | 0.912 | 4.700 | — |
| reverse-right | FAIL | 0.017 | 0.249 | 1.077 | 6.150 | braking |
| turn-left | FAIL | 0.051 | 0.212 | 0.685 | 8.100 | braking |
| turn-right | FAIL | 0.033 | 0.172 | 0.798 | 6.200 | braking |
| climb-forward | FAIL | 0.014 | 0.204 | 0.876 | 5.550 | transient_height |
| descend-left | FAIL | 0.025 | 0.381 | 1.520 | 4.850 | transient_height, active_attitude |
| vertical-cycle | FAIL | 0.013 | 0.108 | 0.045 | — | transient_height, active_attitude |
| reverse-command | PASS | 0.070 | 0.149 | 1.011 | 4.400 | — |
| brake | PASS | 0.016 | 0.030 | 0.081 | 5.900 | — |
| slalom | FAIL | 0.017 | 0.219 | 2.019 | 4.600 | motion |
| gust | PASS | 0.006 | 0.158 | 0.634 | — | — |
| load-swing | FAIL | 0.102 | 0.175 | 13.510 | — | tail_tilt, tail_speed_rms, final_speed |
| recovery-diagonal | PASS | 0.009 | 0.261 | 1.320 | — | — |
| recovery-inverted | FAIL | 0.075 | 0.147 | 0.528 | — | transient_height |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/telemetry-delay-fpv.pdf` et `traces/telemetry-delay/fpv/`.
