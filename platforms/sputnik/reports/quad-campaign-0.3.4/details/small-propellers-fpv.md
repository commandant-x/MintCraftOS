# small-propellers / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.001 | 0.002 | 0.000 | — | — |
| cold-hover | PASS | 0.000 | 0.002 | 0.000 | — | — |
| climb | PASS | 0.004 | 0.005 | 0.000 | — | — |
| descend | PASS | 0.002 | 0.006 | 0.000 | — | — |
| forward | PASS | 0.002 | 0.006 | 0.056 | 4.750 | — |
| reverse | PASS | 0.002 | 0.006 | 0.056 | 4.750 | — |
| left | PASS | 0.002 | 0.014 | 0.054 | 5.100 | — |
| right | PASS | 0.002 | 0.014 | 0.054 | 5.100 | — |
| forward-left | PASS | 0.002 | 0.004 | 0.051 | 5.050 | — |
| forward-right | PASS | 0.000 | 0.010 | 0.048 | 5.050 | — |
| reverse-left | PASS | 0.000 | 0.010 | 0.048 | 5.050 | — |
| reverse-right | PASS | 0.002 | 0.004 | 0.051 | 5.050 | — |
| turn-left | PASS | 0.004 | 0.007 | 0.045 | 5.200 | — |
| turn-right | PASS | 0.003 | 0.006 | 0.053 | 5.200 | — |
| climb-forward | PASS | 0.003 | 0.006 | 0.043 | 5.200 | — |
| descend-left | PASS | 0.007 | 0.008 | 0.043 | 5.050 | — |
| vertical-cycle | PASS | 0.000 | 0.002 | 0.000 | — | — |
| reverse-command | PASS | 0.003 | 0.010 | 0.041 | 3.850 | — |
| brake | PASS | 0.002 | 0.006 | 0.056 | 4.750 | — |
| slalom | PASS | 0.001 | 0.005 | 0.057 | 5.350 | — |
| gust | PASS | 0.001 | 0.005 | 0.048 | — | — |
| load-swing | FAIL | 0.021 | 0.080 | 16.878 | — | tail_tilt, tail_speed_rms, final_speed |
| recovery-diagonal | PASS | 0.002 | 0.005 | 0.053 | — | — |
| recovery-inverted | FAIL | 0.228 | 0.282 | 0.037 | — | transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/small-propellers-fpv.pdf` et `traces/small-propellers/fpv/`.
