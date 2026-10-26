# telemetry-delay / standard

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.073 | 0.200 | 0.752 | — | — |
| cold-hover | PASS | 0.002 | 0.123 | 0.609 | — | — |
| climb | FAIL | 0.071 | 0.117 | 0.685 | — | transient_height, active_vertical_rate |
| descend | FAIL | 0.120 | 0.200 | 0.650 | — | transient_height |
| forward | FAIL | 0.015 | 0.085 | 0.583 | 10.000 | transient_height, active_height, braking |
| reverse | FAIL | 0.067 | 0.187 | 0.609 | 11.600 | transient_height, active_height, braking |
| left | FAIL | 0.066 | 0.189 | 0.556 | 10.300 | transient_height, active_height, braking |
| right | FAIL | 0.043 | 0.185 | 0.662 | 10.700 | transient_height, active_attitude, active_height, braking |
| forward-left | FAIL | 0.068 | 0.138 | 0.698 | 11.050 | transient_height, active_height, braking |
| forward-right | FAIL | 0.104 | 0.227 | 0.878 | 11.300 | transient_height, active_height, braking |
| reverse-left | FAIL | 0.047 | 0.108 | 0.599 | 11.250 | transient_height, active_height, braking |
| reverse-right | FAIL | 0.004 | 0.100 | 0.665 | 11.250 | transient_height, active_height, braking |
| turn-left | FAIL | 0.032 | 0.120 | 0.595 | 3.850 | transient_height, active_attitude, active_height |
| turn-right | FAIL | 0.005 | 0.162 | 0.685 | 4.000 | transient_height, active_attitude, active_height |
| climb-forward | FAIL | 0.101 | 0.233 | 0.719 | 4.700 | transient_height, active_vertical_rate |
| descend-left | FAIL | 0.036 | 0.190 | 0.779 | 13.450 | transient_height, active_attitude, active_vertical_rate, braking |
| vertical-cycle | FAIL | 0.069 | 0.045 | 0.586 | — | transient_height |
| reverse-command | FAIL | 0.019 | 0.172 | 0.649 | 5.700 | transient_height, active_attitude, active_height, motion |
| brake | FAIL | 0.015 | 0.085 | 0.583 | 10.000 | transient_height, active_height, braking |
| slalom | FAIL | 0.084 | 0.120 | 0.722 | 6.550 | active_attitude, active_height, motion, braking |
| gust | PASS | 0.058 | 0.198 | 0.695 | — | — |
| load-swing | FAIL | 16.025 | 3.425 | 28.226 | — | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height |
| recovery-diagonal | PASS | 0.059 | 0.259 | 0.885 | — | — |
| recovery-inverted | FAIL | 0.111 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/telemetry-delay-standard.pdf` et `traces/telemetry-delay/standard/`.
