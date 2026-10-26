# shifted-com / standard

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | FAIL | 0.011 | 0.055 | 0.753 | — | tail_speed_rms, final_speed |
| cold-hover | FAIL | 0.002 | 0.045 | 0.812 | — | tail_speed_rms, final_speed |
| climb | FAIL | 0.004 | 0.032 | 0.779 | — | tail_speed_rms, final_speed, transient_height |
| descend | FAIL | 0.011 | 0.058 | 0.822 | — | tail_speed_rms, final_speed, transient_height |
| forward | FAIL | 0.008 | 0.051 | 0.766 | — | tail_speed_rms, final_speed, active_height, braking |
| reverse | FAIL | 0.006 | 0.041 | 0.738 | — | tail_speed_rms, final_speed, transient_height, active_height, braking |
| left | FAIL | 0.000 | 0.025 | 0.774 | — | tail_speed_rms, final_speed, active_height, braking |
| right | FAIL | 0.035 | 0.062 | 0.767 | — | tail_speed_rms, final_speed, transient_height, active_attitude, active_height, braking |
| forward-left | FAIL | 0.028 | 0.094 | 0.783 | — | tail_speed_rms, final_speed, active_height, braking |
| forward-right | FAIL | 0.004 | 0.039 | 0.809 | — | tail_speed_rms, final_speed, transient_height, active_height, braking |
| reverse-left | FAIL | 0.003 | 0.040 | 0.776 | — | tail_speed_rms, final_speed, active_attitude, active_height, braking |
| reverse-right | FAIL | 0.016 | 0.065 | 0.799 | — | tail_speed_rms, final_speed, transient_height, active_height, braking |
| turn-left | FAIL | 0.018 | 0.061 | 0.817 | — | tail_speed_rms, final_speed, transient_height, active_attitude, active_height, motion, braking |
| turn-right | FAIL | 0.004 | 0.078 | 0.807 | — | tail_speed_rms, final_speed, transient_height, active_attitude, active_height, braking |
| climb-forward | FAIL | 0.000 | 0.031 | 0.780 | — | tail_speed_rms, final_speed, transient_height, active_attitude, active_vertical_rate, braking |
| descend-left | FAIL | 0.026 | 0.069 | 0.734 | 4.000 | tail_speed_rms, final_speed, transient_height, active_attitude |
| vertical-cycle | FAIL | 0.028 | 0.073 | 0.804 | — | tail_speed_rms, final_speed, transient_height, active_attitude |
| reverse-command | FAIL | 0.008 | 0.073 | 0.742 | — | tail_speed_rms, final_speed, active_attitude, active_height, braking |
| brake | FAIL | 0.008 | 0.051 | 0.766 | — | tail_speed_rms, final_speed, active_height, braking |
| slalom | FAIL | 0.005 | 0.032 | 0.824 | — | tail_speed_rms, final_speed, transient_height, active_attitude, active_height, motion, braking |
| gust | FAIL | 0.026 | 0.060 | 0.795 | — | tail_speed_rms, final_speed |
| load-swing | FAIL | 0.577 | 0.052 | 0.902 | — | tail_height_rms, tail_speed_rms, final_speed |
| recovery-diagonal | FAIL | 0.018 | 0.041 | 0.751 | — | tail_speed_rms, final_speed, recovery |
| recovery-inverted | FAIL | 0.038 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/shifted-com-standard.pdf` et `traces/shifted-com/standard/`.
