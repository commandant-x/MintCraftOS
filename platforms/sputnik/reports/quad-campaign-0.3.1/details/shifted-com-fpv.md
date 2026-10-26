# shifted-com / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.006 | 0.032 | 0.163 | — | — |
| cold-hover | PASS | 0.011 | 0.055 | 0.169 | — | — |
| climb | FAIL | 0.007 | 0.031 | 0.249 | — | transient_height, active_attitude |
| descend | FAIL | 0.012 | 0.068 | 0.257 | — | active_attitude, active_vertical_rate |
| forward | FAIL | 0.008 | 0.023 | 0.142 | 17.200 | transient_height, active_attitude, braking |
| reverse | FAIL | 0.010 | 0.086 | 0.194 | 18.050 | transient_height, active_attitude, active_height, braking |
| left | FAIL | 0.006 | 0.062 | 0.185 | 18.200 | transient_height, active_attitude, braking |
| right | FAIL | 0.001 | 0.035 | 0.232 | 17.200 | transient_height, active_attitude, active_height, braking |
| forward-left | FAIL | 0.000 | 0.047 | 0.245 | 18.600 | transient_height, active_attitude, braking |
| forward-right | FAIL | 0.010 | 0.013 | 0.173 | 16.200 | transient_height, active_attitude, active_height, braking |
| reverse-left | FAIL | 0.008 | 0.076 | 0.335 | 17.500 | transient_height, active_attitude, braking |
| reverse-right | FAIL | 0.004 | 0.067 | 0.269 | 17.000 | transient_height, active_attitude, active_height, braking |
| turn-left | FAIL | 0.001 | 0.031 | 0.289 | 16.450 | transient_height, active_attitude, active_height, motion, braking |
| turn-right | FAIL | 0.012 | 0.029 | 0.244 | 16.750 | transient_height, active_attitude, active_height, motion, braking |
| climb-forward | FAIL | 0.024 | 0.082 | 0.434 | 21.850 | transient_height, active_attitude, braking |
| descend-left | FAIL | 0.004 | 0.035 | 0.215 | 18.300 | transient_height, active_attitude, braking |
| vertical-cycle | FAIL | 0.007 | 0.218 | 0.833 | — | transient_height, active_attitude, active_vertical_rate |
| reverse-command | FAIL | 0.001 | 0.092 | 0.517 | 17.350 | transient_height, active_attitude, active_height, braking |
| brake | FAIL | 0.008 | 0.023 | 0.142 | 17.200 | transient_height, active_attitude, braking |
| slalom | FAIL | 0.030 | 0.066 | 0.292 | 19.000 | transient_height, active_attitude, active_height, motion, braking |
| gust | PASS | 0.010 | 0.038 | 0.239 | — | — |
| load-swing | PASS | 0.030 | 0.054 | 0.305 | — | — |
| recovery-diagonal | FAIL | 0.014 | 0.037 | 0.179 | — | recovery |
| recovery-inverted | FAIL | 0.024 | 0.059 | 0.332 | — | recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/shifted-com-fpv.pdf` et `traces/shifted-com/fpv/`.
