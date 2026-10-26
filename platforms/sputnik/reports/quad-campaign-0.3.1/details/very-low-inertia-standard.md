# very-low-inertia / standard

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.010 | 0.000 | — | — |
| cold-hover | PASS | 0.001 | 0.009 | 0.000 | — | — |
| climb | FAIL | 0.004 | 0.012 | 0.000 | — | transient_height |
| descend | FAIL | 0.009 | 0.019 | 0.000 | — | transient_height |
| forward | FAIL | 0.002 | 0.010 | 0.000 | 0.700 | active_attitude, motion |
| reverse | FAIL | 0.002 | 0.010 | 0.000 | 0.700 | active_attitude, motion |
| left | FAIL | 0.002 | 0.009 | 0.022 | 13.450 | active_attitude, braking |
| right | FAIL | 0.013 | 0.025 | 1.540 | — | tail_speed_rms, final_speed, active_attitude, braking |
| forward-left | FAIL | 0.003 | 0.008 | 1.609 | 15.300 | tail_speed_rms, final_speed, transient_height, active_height, braking |
| forward-right | FAIL | 0.001 | 0.009 | 0.028 | 14.000 | transient_height, active_height, braking |
| reverse-left | FAIL | 0.001 | 0.009 | 0.028 | 14.000 | transient_height, active_height, braking |
| reverse-right | FAIL | 0.003 | 0.008 | 1.609 | 15.300 | tail_speed_rms, final_speed, transient_height, active_height, braking |
| turn-left | FAIL | 0.000 | 0.009 | 0.042 | 15.150 | active_attitude, active_height, motion, braking |
| turn-right | FAIL | 0.004 | 0.009 | 0.218 | 41.000 | active_attitude, active_height, motion, braking |
| climb-forward | FAIL | 0.002 | 0.011 | 0.000 | 0.700 | transient_height, active_attitude, motion |
| descend-left | FAIL | 0.008 | 0.015 | 2.405 | — | tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, braking |
| vertical-cycle | FAIL | 0.026 | 0.042 | 0.000 | — | transient_height |
| reverse-command | FAIL | 0.002 | 0.010 | 0.000 | 0.700 | active_attitude, motion |
| brake | FAIL | 0.002 | 0.010 | 0.000 | 0.700 | active_attitude, motion |
| slalom | FAIL | 0.013 | 0.060 | 1.006 | 29.800 | tail_speed_rms, final_speed, active_attitude, active_height, motion, braking |
| gust | FAIL | 0.001 | 0.007 | 1.045 | — | tail_speed_rms, final_speed |
| load-swing | FAIL | 0.238 | 1.683 | 1.763 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_speed_rms, final_speed |
| recovery-diagonal | PASS | 0.002 | 0.010 | 0.009 | — | — |
| recovery-inverted | FAIL | 0.008 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/very-low-inertia-standard.pdf` et `traces/very-low-inertia/standard/`.
