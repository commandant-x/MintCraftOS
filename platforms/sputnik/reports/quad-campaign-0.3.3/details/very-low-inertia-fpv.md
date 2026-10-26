# very-low-inertia / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.008 | 0.000 | — | — |
| cold-hover | PASS | 0.002 | 0.007 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.011 | 0.000 | — | — |
| descend | PASS | 0.001 | 0.010 | 0.000 | — | — |
| forward | FAIL | 0.002 | 0.015 | 4.555 | — | tail_speed_rms, final_speed, active_attitude, braking |
| reverse | FAIL | 0.000 | 0.017 | 4.555 | — | tail_speed_rms, final_speed, active_attitude, braking |
| left | FAIL | 0.000 | 0.008 | 3.133 | — | tail_speed_rms, final_speed, active_attitude, braking |
| right | FAIL | 0.000 | 0.008 | 3.133 | — | tail_speed_rms, final_speed, active_attitude, braking |
| forward-left | FAIL | 0.018 | 0.032 | 8.886 | — | tail_tilt, tail_speed_rms, final_speed, active_attitude, braking |
| forward-right | FAIL | 0.007 | 0.031 | 6.416 | — | tail_tilt, tail_speed_rms, final_speed, active_attitude, braking |
| reverse-left | FAIL | 0.007 | 0.031 | 6.416 | — | tail_tilt, tail_speed_rms, final_speed, active_attitude, braking |
| reverse-right | FAIL | 0.018 | 0.032 | 8.886 | — | tail_tilt, tail_speed_rms, final_speed, active_attitude, braking |
| turn-left | FAIL | 0.001 | 0.010 | 3.827 | — | tail_speed_rms, final_speed, active_attitude, motion, braking |
| turn-right | FAIL | 0.006 | 0.011 | 3.144 | — | tail_speed_rms, final_speed, active_attitude, motion, braking |
| climb-forward | FAIL | 0.046 | 0.159 | 6.784 | — | tail_tilt, tail_speed_rms, final_speed, active_attitude, braking |
| descend-left | FAIL | 0.003 | 0.010 | 4.329 | — | tail_speed_rms, final_speed, transient_tilt, active_attitude, braking |
| vertical-cycle | PASS | 0.002 | 0.009 | 0.000 | — | — |
| reverse-command | FAIL | 0.000 | 0.011 | 0.034 | 21.300 | active_attitude, braking |
| brake | FAIL | 0.002 | 0.015 | 4.555 | — | tail_speed_rms, final_speed, active_attitude, braking |
| slalom | FAIL | 0.008 | 0.026 | 5.529 | — | tail_tilt, tail_speed_rms, final_speed, active_attitude, braking |
| gust | PASS | 0.000 | 0.008 | 0.000 | — | — |
| load-swing | PASS | 0.003 | 0.017 | 0.124 | — | — |
| recovery-diagonal | FAIL | 0.003 | 0.009 | 3.338 | — | tail_speed_rms, final_speed, recovery |
| recovery-inverted | FAIL | 80.880 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/very-low-inertia-fpv.pdf` et `traces/very-low-inertia/fpv/`.
