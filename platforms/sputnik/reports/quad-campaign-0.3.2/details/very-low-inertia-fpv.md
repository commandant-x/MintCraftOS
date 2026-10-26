# very-low-inertia / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.001 | 0.014 | 0.000 | — | — |
| cold-hover | PASS | 0.005 | 0.022 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.023 | 0.000 | — | — |
| descend | PASS | 0.000 | 0.044 | 0.000 | — | — |
| forward | FAIL | 0.007 | 0.023 | 8.368 | — | tail_tilt, tail_speed_rms, final_speed, active_attitude, braking |
| reverse | FAIL | 0.005 | 0.014 | 8.920 | — | tail_tilt, tail_speed_rms, final_speed, active_attitude, braking |
| left | FAIL | 0.052 | 0.185 | 7.129 | — | tail_tilt, tail_speed_rms, final_speed, active_attitude, braking |
| right | FAIL | 0.052 | 0.185 | 7.129 | — | tail_tilt, tail_speed_rms, final_speed, active_attitude, braking |
| forward-left | FAIL | 0.016 | 0.101 | 10.184 | — | tail_tilt, tail_speed_rms, final_speed, active_attitude, braking |
| forward-right | FAIL | 0.016 | 0.101 | 10.184 | — | tail_tilt, tail_speed_rms, final_speed, active_attitude, braking |
| reverse-left | FAIL | 0.016 | 0.101 | 10.184 | — | tail_tilt, tail_speed_rms, final_speed, active_attitude, braking |
| reverse-right | FAIL | 0.016 | 0.101 | 10.184 | — | tail_tilt, tail_speed_rms, final_speed, active_attitude, braking |
| turn-left | FAIL | 0.002 | 0.019 | 2.788 | — | tail_speed_rms, final_speed, active_attitude, motion, braking |
| turn-right | FAIL | 0.009 | 0.021 | 5.669 | — | tail_tilt, tail_speed_rms, final_speed, active_attitude, motion, braking |
| climb-forward | FAIL | 0.003 | 0.014 | 8.246 | — | tail_tilt, tail_speed_rms, final_speed, active_attitude, braking |
| descend-left | FAIL | 0.001 | 0.021 | 3.752 | — | tail_speed_rms, final_speed, transient_tilt, active_attitude, braking |
| vertical-cycle | PASS | 0.005 | 0.020 | 0.000 | — | — |
| reverse-command | FAIL | 0.007 | 0.016 | 3.062 | — | tail_speed_rms, final_speed, active_attitude, braking |
| brake | FAIL | 0.007 | 0.023 | 8.368 | — | tail_tilt, tail_speed_rms, final_speed, active_attitude, braking |
| slalom | FAIL | 0.002 | 0.009 | 5.753 | — | tail_tilt, tail_speed_rms, final_speed, active_attitude, motion, braking |
| gust | PASS | 0.005 | 0.025 | 0.000 | — | — |
| load-swing | PASS | 0.006 | 0.095 | 0.021 | — | — |
| recovery-diagonal | FAIL | 0.002 | 0.007 | 3.281 | — | tail_speed_rms, final_speed, recovery |
| recovery-inverted | FAIL | 81.470 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/very-low-inertia-fpv.pdf` et `traces/very-low-inertia/fpv/`.
