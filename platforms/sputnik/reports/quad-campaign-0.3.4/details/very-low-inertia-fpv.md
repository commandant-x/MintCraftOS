# very-low-inertia / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.008 | 0.000 | — | — |
| cold-hover | PASS | 0.002 | 0.007 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.011 | 0.000 | — | — |
| descend | PASS | 0.001 | 0.010 | 0.000 | — | — |
| forward | FAIL | 0.003 | 0.007 | 1.383 | 5.700 | tail_speed_rms, final_speed, active_attitude |
| reverse | FAIL | 0.003 | 0.007 | 1.378 | 5.700 | tail_speed_rms, final_speed, active_attitude |
| left | FAIL | 0.004 | 0.017 | 4.432 | — | tail_speed_rms, final_speed, active_attitude, braking |
| right | FAIL | 0.004 | 0.017 | 4.432 | — | tail_speed_rms, final_speed, active_attitude, braking |
| forward-left | FAIL | 0.020 | 0.167 | 7.771 | — | tail_tilt, tail_speed_rms, final_speed, active_attitude, braking |
| forward-right | FAIL | 0.003 | 0.016 | 4.492 | — | tail_speed_rms, final_speed, active_attitude, braking |
| reverse-left | FAIL | 0.003 | 0.016 | 4.492 | — | tail_speed_rms, final_speed, active_attitude, braking |
| reverse-right | FAIL | 0.020 | 0.167 | 7.771 | — | tail_tilt, tail_speed_rms, final_speed, active_attitude, braking |
| turn-left | FAIL | 0.005 | 0.008 | 1.277 | — | tail_speed_rms, final_speed, active_attitude, motion, braking |
| turn-right | FAIL | 0.004 | 0.014 | 2.920 | — | tail_speed_rms, final_speed, active_attitude, motion, braking |
| climb-forward | FAIL | 0.007 | 0.013 | 0.115 | 5.500 | active_attitude |
| descend-left | FAIL | 0.002 | 0.018 | 5.367 | — | tail_tilt, tail_speed_rms, final_speed, active_attitude, braking |
| vertical-cycle | PASS | 0.002 | 0.009 | 0.000 | — | — |
| reverse-command | FAIL | 0.002 | 0.025 | 2.479 | — | tail_speed_rms, final_speed, active_attitude, braking |
| brake | FAIL | 0.003 | 0.007 | 1.383 | 5.700 | tail_speed_rms, final_speed, active_attitude |
| slalom | FAIL | 0.006 | 0.009 | 0.069 | 6.700 | active_attitude, motion, braking |
| gust | PASS | 0.000 | 0.008 | 0.000 | — | — |
| load-swing | FAIL | 0.106 | 0.284 | 2.149 | — | tail_speed_rms, final_speed |
| recovery-diagonal | FAIL | 0.008 | 0.028 | 2.736 | — | tail_speed_rms, final_speed, recovery |
| recovery-inverted | FAIL | 80.880 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/very-low-inertia-fpv.pdf` et `traces/very-low-inertia/fpv/`.
