# high-altitude / standard

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | FAIL | 0.003 | 0.008 | 2.071 | — | final_speed |
| cold-hover | FAIL | 0.002 | 0.010 | 2.078 | — | final_speed |
| climb | FAIL | 0.002 | 0.007 | 2.145 | — | final_speed, transient_height |
| descend | FAIL | 0.002 | 0.025 | 2.076 | — | final_speed, transient_height |
| forward | FAIL | 0.003 | 0.012 | 2.101 | — | final_speed, active_height, braking |
| reverse | FAIL | 0.000 | 0.009 | 2.073 | 5.450 | final_speed |
| left | FAIL | 0.001 | 0.010 | 2.078 | 6.250 | final_speed, transient_height, active_height, braking |
| right | FAIL | 0.003 | 0.009 | 2.107 | 5.550 | final_speed |
| forward-left | FAIL | 0.003 | 0.012 | 2.115 | 6.200 | final_speed, transient_height, active_height, braking |
| forward-right | FAIL | 0.001 | 0.010 | 2.073 | 8.900 | final_speed, braking |
| reverse-left | FAIL | 0.000 | 0.012 | 2.083 | — | final_speed, active_height, braking |
| reverse-right | FAIL | 0.000 | 0.007 | 2.088 | 4.750 | final_speed |
| turn-left | FAIL | 0.002 | 0.009 | 2.088 | 4.000 | final_speed, active_attitude, active_height, motion |
| turn-right | FAIL | 0.004 | 0.010 | 2.090 | 4.600 | final_speed, active_attitude, active_height |
| climb-forward | FAIL | 0.004 | 0.012 | 2.075 | 6.200 | final_speed, transient_height, active_vertical_rate, braking |
| descend-left | FAIL | 0.002 | 0.016 | 2.131 | 4.900 | final_speed, transient_height |
| vertical-cycle | FAIL | 0.015 | 0.055 | 2.119 | — | final_speed, transient_height |
| reverse-command | FAIL | 0.004 | 0.009 | 2.112 | 4.000 | final_speed, active_height |
| brake | FAIL | 0.003 | 0.012 | 2.101 | — | final_speed, active_height, braking |
| slalom | FAIL | 0.000 | 0.011 | 2.087 | 1.550 | final_speed, active_attitude, motion |
| gust | FAIL | 0.001 | 0.009 | 2.093 | — | final_speed |
| load-swing | FAIL | 0.646 | 0.008 | 1.652 | — | tail_height_rms |
| recovery-diagonal | FAIL | 0.002 | 0.008 | 2.108 | — | final_speed |
| recovery-inverted | FAIL | 0.090 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/high-altitude-standard.pdf` et `traces/high-altitude/standard/`.
