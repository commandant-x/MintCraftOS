# low-inertia / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.008 | 0.000 | — | — |
| cold-hover | PASS | 0.002 | 0.007 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.011 | 0.000 | — | — |
| descend | PASS | 0.001 | 0.010 | 0.000 | — | — |
| forward | PASS | 0.054 | 0.110 | 0.589 | 5.500 | — |
| reverse | PASS | 0.005 | 0.078 | 0.466 | 5.800 | — |
| left | PASS | 0.021 | 0.115 | 0.609 | 4.450 | — |
| right | PASS | 0.021 | 0.115 | 0.609 | 4.450 | — |
| forward-left | PASS | 0.002 | 0.078 | 0.424 | 5.350 | — |
| forward-right | PASS | 0.017 | 0.104 | 0.776 | 5.100 | — |
| reverse-left | PASS | 0.017 | 0.104 | 0.776 | 5.100 | — |
| reverse-right | PASS | 0.002 | 0.078 | 0.424 | 5.350 | — |
| turn-left | PASS | 0.007 | 0.106 | 0.479 | 4.800 | — |
| turn-right | PASS | 0.028 | 0.097 | 0.606 | 5.250 | — |
| climb-forward | FAIL | 0.011 | 0.099 | 0.378 | 6.200 | braking |
| descend-left | PASS | 0.021 | 0.052 | 0.601 | 5.500 | — |
| vertical-cycle | PASS | 0.002 | 0.009 | 0.000 | — | — |
| reverse-command | PASS | 0.059 | 0.125 | 0.630 | 5.800 | — |
| brake | PASS | 0.054 | 0.110 | 0.589 | 5.500 | — |
| slalom | FAIL | 0.006 | 0.088 | 0.536 | 5.350 | active_attitude, motion |
| gust | PASS | 0.005 | 0.062 | 0.587 | — | — |
| load-swing | PASS | 0.017 | 0.053 | 0.506 | — | — |
| recovery-diagonal | PASS | 0.011 | 0.108 | 0.478 | — | — |
| recovery-inverted | FAIL | 80.233 | — | — | — | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/low-inertia-fpv.pdf` et `traces/low-inertia/fpv/`.
