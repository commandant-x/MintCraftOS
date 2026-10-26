# weak-one-rotor / standard

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | FAIL | 0.058 | 0.193 | 1.050 | — | tail_speed_rms, final_speed |
| cold-hover | FAIL | 0.038 | 0.221 | 1.447 | — | tail_speed_rms, final_speed |
| climb | FAIL | 0.016 | 0.061 | 0.742 | — | tail_speed_rms, final_speed, transient_height, active_vertical_rate |
| descend | FAIL | 0.017 | 0.139 | 1.198 | — | final_speed, transient_height |
| forward | FAIL | 0.023 | 0.114 | 1.068 | 7.650 | tail_speed_rms, final_speed, transient_height, active_height, braking |
| reverse | FAIL | 0.021 | 0.111 | 1.352 | 13.700 | tail_speed_rms, final_speed, active_height, braking |
| left | FAIL | 0.065 | 0.196 | 1.473 | 40.000 | final_speed, transient_height, active_height, braking |
| right | FAIL | 0.008 | 0.168 | 0.959 | 4.950 | tail_speed_rms, final_speed, active_height |
| forward-left | FAIL | 0.016 | 0.166 | 1.048 | 7.750 | final_speed, transient_height, active_height, braking |
| forward-right | FAIL | 0.012 | 0.160 | 0.799 | 17.950 | tail_speed_rms, final_speed, transient_height, active_height, braking |
| reverse-left | FAIL | 0.008 | 0.221 | 1.092 | 9.300 | tail_speed_rms, final_speed, transient_height, active_height, braking |
| reverse-right | FAIL | 0.083 | 0.289 | 1.469 | 10.900 | tail_speed_rms, final_speed, active_height, braking |
| turn-left | FAIL | 0.019 | 0.129 | 0.819 | 3.450 | tail_speed_rms, final_speed, transient_height, active_attitude, active_height |
| turn-right | FAIL | 0.013 | 0.122 | 0.932 | 8.850 | tail_speed_rms, final_speed, transient_height, active_attitude, active_height, braking |
| climb-forward | FAIL | 0.061 | 0.223 | 0.861 | — | tail_speed_rms, final_speed, transient_height, active_vertical_rate, braking |
| descend-left | FAIL | 0.067 | 0.150 | 1.132 | 9.850 | final_speed, transient_height, active_attitude, braking |
| vertical-cycle | FAIL | 0.019 | 0.140 | 0.975 | — | tail_speed_rms, transient_height |
| reverse-command | FAIL | 0.009 | 0.263 | 1.528 | 7.700 | tail_speed_rms, final_speed, transient_height, active_attitude, active_height, motion, braking |
| brake | FAIL | 0.023 | 0.114 | 1.068 | 7.650 | tail_speed_rms, final_speed, transient_height, active_height, braking |
| slalom | FAIL | 0.041 | 0.314 | 1.667 | 3.400 | tail_speed_rms, final_speed, transient_height, active_attitude, active_height, motion |
| gust | FAIL | 0.068 | 0.120 | 1.010 | — | tail_speed_rms, final_speed |
| load-swing | FAIL | 5.679 | 2.155 | 19.126 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height |
| recovery-diagonal | FAIL | 0.110 | 0.160 | 1.103 | — | tail_speed_rms, recovery |
| recovery-inverted | FAIL | 0.449 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/weak-one-rotor-standard.pdf` et `traces/weak-one-rotor/standard/`.
