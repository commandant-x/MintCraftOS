# radio-5ticks / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.000 | 0.032 | 0.000 | — | — |
| cold-hover | PASS | 0.010 | 0.032 | 0.000 | — | — |
| climb | FAIL | 0.000 | 0.021 | 0.000 | — | transient_height |
| descend | FAIL | 0.014 | 0.052 | 0.000 | — | transient_height |
| forward | FAIL | 0.074 | 0.466 | 13.781 | — | tail_tilt, tail_speed_rms, final_speed, braking |
| reverse | FAIL | 0.009 | 0.306 | 13.125 | — | tail_tilt, tail_speed_rms, final_speed, braking |
| left | FAIL | 0.043 | 0.147 | 13.851 | 7.800 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| right | FAIL | 0.076 | 0.137 | 14.757 | 7.900 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_height, braking |
| forward-left | FAIL | 0.171 | 0.341 | 12.630 | — | tail_tilt, tail_speed_rms, final_speed, transient_height, braking |
| forward-right | FAIL | 0.007 | 0.149 | 14.815 | — | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, braking |
| reverse-left | FAIL | 0.061 | 0.121 | 14.842 | — | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, braking |
| reverse-right | FAIL | 0.059 | 0.107 | 13.747 | — | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, braking |
| turn-left | FAIL | 0.049 | 0.144 | 14.031 | — | tail_tilt, tail_speed_rms, final_speed, braking |
| turn-right | FAIL | 0.082 | 0.112 | 14.423 | — | tail_tilt, tail_speed_rms, final_speed, braking |
| climb-forward | FAIL | 0.396 | 0.976 | 13.191 | 7.950 | tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, braking |
| descend-left | FAIL | 0.080 | 0.135 | 13.032 | — | tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, braking |
| vertical-cycle | FAIL | 0.009 | 0.024 | 0.000 | — | transient_height |
| reverse-command | FAIL | 0.069 | 0.436 | 13.281 | — | tail_tilt, tail_speed_rms, final_speed, transient_height, active_attitude, active_height, braking |
| brake | FAIL | 0.074 | 0.466 | 13.781 | — | tail_tilt, tail_speed_rms, final_speed, braking |
| slalom | FAIL | 0.008 | 0.144 | 14.731 | — | tail_tilt, tail_speed_rms, final_speed, active_attitude, motion, braking |
| gust | FAIL | 0.009 | 0.754 | 14.720 | — | tail_tilt, tail_speed_rms, final_speed |
| load-swing | FAIL | 0.314 | 3.671 | 25.929 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed |
| recovery-diagonal | FAIL | 0.009 | 0.185 | 14.701 | — | tail_tilt, tail_speed_rms, final_speed, recovery |
| recovery-inverted | FAIL | 52.182 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/radio-5ticks-fpv.pdf` et `traces/radio-5ticks/fpv/`.
