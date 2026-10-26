# high-altitude / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.025 | 0.060 | 2.334 | — | — |
| cold-hover | PASS | 0.038 | 0.090 | 2.234 | — | — |
| climb | FAIL | 0.014 | 0.087 | 2.291 | — | transient_height |
| descend | FAIL | 0.016 | 0.064 | 2.282 | — | transient_height, active_attitude, active_vertical_rate |
| forward | FAIL | 0.110 | 0.216 | 2.244 | 8.300 | transient_height, braking |
| reverse | FAIL | 0.042 | 0.061 | 2.288 | 5.400 | transient_height, active_height |
| left | FAIL | 0.019 | 0.080 | 2.270 | 5.100 | transient_height |
| right | FAIL | 0.006 | 0.079 | 2.273 | 5.400 | transient_height |
| forward-left | FAIL | 0.204 | 0.194 | 2.331 | 5.850 | transient_height |
| forward-right | FAIL | 0.089 | 0.125 | 2.280 | 6.050 | transient_height, braking |
| reverse-left | FAIL | 0.154 | 0.236 | 2.326 | 8.450 | transient_height, braking |
| reverse-right | FAIL | 0.006 | 0.078 | 2.277 | 6.050 | transient_height, active_height, braking |
| turn-left | FAIL | 0.489 | 0.654 | 2.325 | 3.100 | tail_height_peak, tail_height_rms, transient_height, active_attitude, active_height |
| turn-right | FAIL | 0.058 | 0.079 | 2.277 | 7.000 | transient_height, active_height, braking |
| climb-forward | FAIL | 0.784 | 0.965 | 2.218 | 9.800 | tail_height_peak, tail_height_rms, transient_height, braking |
| descend-left | FAIL | 0.028 | 0.064 | 2.290 | 3.550 | transient_height |
| vertical-cycle | FAIL | 0.014 | 0.026 | 2.236 | — | transient_height, active_attitude, active_vertical_rate, motion |
| reverse-command | FAIL | 0.155 | 0.248 | 2.271 | 5.350 | transient_height, active_height |
| brake | FAIL | 0.110 | 0.216 | 2.244 | 8.300 | transient_height, braking |
| slalom | FAIL | 0.372 | 0.486 | 2.259 | 6.350 | tail_height_rms, transient_height, active_attitude, active_height, motion, braking |
| gust | PASS | 0.010 | 0.068 | 2.350 | — | — |
| load-swing | FAIL | 35.238 | 36.319 | 19.539 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height |
| recovery-diagonal | PASS | 0.016 | 0.074 | 2.279 | — | — |
| recovery-inverted | FAIL | 2.034 | 2.230 | 4.978 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_speed_rms, transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/high-altitude-fpv.pdf` et `traces/high-altitude/fpv/`.
