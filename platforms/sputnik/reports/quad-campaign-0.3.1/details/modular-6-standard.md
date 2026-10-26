# modular-6 / standard

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.025 | 0.051 | 0.000 | — | — |
| cold-hover | PASS | 0.010 | 0.029 | 0.000 | — | — |
| climb | FAIL | 0.003 | 0.012 | 0.000 | — | transient_height |
| descend | FAIL | 0.006 | 0.016 | 0.000 | — | transient_height |
| forward | PASS | 0.008 | 0.057 | 0.162 | 5.800 | — |
| reverse | PASS | 0.001 | 0.037 | 0.167 | 5.850 | — |
| left | PASS | 0.009 | 0.037 | 0.146 | 5.850 | — |
| right | PASS | 0.000 | 0.024 | 0.197 | 6.000 | — |
| forward-left | PASS | 0.001 | 0.057 | 0.171 | 5.800 | — |
| forward-right | PASS | 0.012 | 0.037 | 0.267 | 5.800 | — |
| reverse-left | PASS | 0.013 | 0.029 | 0.184 | 5.750 | — |
| reverse-right | PASS | 0.004 | 0.049 | 0.160 | 5.800 | — |
| turn-left | FAIL | 0.010 | 0.031 | 0.259 | 3.350 | active_attitude, motion |
| turn-right | FAIL | 0.017 | 0.037 | 0.207 | 3.450 | active_attitude, motion |
| climb-forward | FAIL | 0.011 | 0.019 | 0.120 | 6.450 | transient_height, braking |
| descend-left | FAIL | 0.001 | 0.037 | 0.224 | 5.200 | transient_height |
| vertical-cycle | FAIL | 0.018 | 0.060 | 0.000 | — | transient_height |
| reverse-command | PASS | 0.018 | 0.033 | 0.206 | 5.050 | — |
| brake | PASS | 0.008 | 0.057 | 0.162 | 5.800 | — |
| slalom | FAIL | 0.013 | 0.041 | 0.209 | 5.200 | active_attitude, motion |
| gust | PASS | 0.013 | 0.042 | 0.222 | — | — |
| load-swing | FAIL | 0.561 | 0.037 | 0.238 | — | tail_height_rms |
| recovery-diagonal | PASS | 0.019 | 0.033 | 0.166 | — | — |
| recovery-inverted | FAIL | 0.008 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/modular-6-standard.pdf` et `traces/modular-6/standard/`.
