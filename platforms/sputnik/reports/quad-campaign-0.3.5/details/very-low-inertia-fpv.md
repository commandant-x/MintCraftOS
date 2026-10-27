# very-low-inertia / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.008 | 0.000 | — | — |
| cold-hover | PASS | 0.001 | 0.007 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.011 | 0.000 | — | — |
| descend | PASS | 0.001 | 0.010 | 0.000 | — | — |
| forward | FAIL | 0.008 | 0.014 | 5.679 | — | tail_tilt, tail_speed_rms, final_speed, active_attitude, braking |
| reverse | FAIL | 0.005 | 0.012 | 5.679 | — | tail_tilt, tail_speed_rms, final_speed, active_attitude, braking |
| left | FAIL | 0.006 | 0.067 | 12.919 | — | tail_tilt, tail_speed_rms, final_speed, transient_tilt, active_attitude, braking |
| right | FAIL | 0.006 | 0.067 | 12.919 | — | tail_tilt, tail_speed_rms, final_speed, transient_tilt, active_attitude, braking |
| forward-left | FAIL | 0.001 | 0.008 | 1.260 | — | tail_speed_rms, final_speed, active_attitude, braking |
| forward-right | FAIL | 0.001 | 0.232 | 6.342 | — | tail_tilt, tail_speed_rms, final_speed, active_attitude, braking |
| reverse-left | FAIL | 0.001 | 0.232 | 6.342 | — | tail_tilt, tail_speed_rms, final_speed, active_attitude, braking |
| reverse-right | FAIL | 0.001 | 0.008 | 1.260 | — | tail_speed_rms, final_speed, active_attitude, braking |
| turn-left | FAIL | 0.006 | 0.015 | 0.152 | 8.250 | active_attitude, motion, braking |
| turn-right | FAIL | 0.004 | 0.008 | 0.064 | 14.350 | active_attitude, motion, braking |
| climb-forward | FAIL | 0.003 | 0.034 | 2.504 | 4.900 | tail_speed_rms, final_speed, active_attitude |
| descend-left | FAIL | 0.001 | 0.018 | 0.009 | 17.650 | transient_height, active_attitude, braking |
| vertical-cycle | PASS | 0.002 | 0.009 | 0.000 | — | — |
| reverse-command | FAIL | 0.001 | 0.006 | 1.262 | — | tail_speed_rms, final_speed, active_attitude, braking |
| brake | FAIL | 0.008 | 0.014 | 5.679 | — | tail_tilt, tail_speed_rms, final_speed, active_attitude, braking |
| slalom | FAIL | 0.013 | 0.026 | 1.772 | 7.500 | tail_speed_rms, final_speed, active_attitude, motion, braking |
| gust | PASS | 0.000 | 0.008 | 0.000 | — | — |
| load-swing | PASS | 0.008 | 0.025 | 0.350 | — | — |
| recovery-diagonal | FAIL | 0.001 | 0.007 | 2.069 | — | tail_speed_rms, final_speed, recovery |
| recovery-inverted | FAIL | 80.880 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/very-low-inertia-fpv.pdf` et `traces/very-low-inertia/fpv/`.
