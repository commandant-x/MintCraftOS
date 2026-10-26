# modular-6 / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.042 | 0.000 | — | — |
| cold-hover | PASS | 0.010 | 0.042 | 0.000 | — | — |
| climb | PASS | 0.004 | 0.012 | 0.000 | — | — |
| descend | PASS | 0.003 | 0.013 | 0.000 | — | — |
| forward | FAIL | 0.141 | 0.129 | 0.309 | 6.350 | transient_height, active_height, braking |
| reverse | FAIL | 0.099 | 0.128 | 0.260 | 6.400 | transient_height, active_height, braking |
| left | FAIL | 0.038 | 0.053 | 0.149 | 5.800 | transient_height |
| right | FAIL | 0.034 | 0.045 | 0.182 | 5.800 | transient_height |
| forward-left | FAIL | 0.021 | 0.062 | 0.212 | 5.450 | transient_height |
| forward-right | FAIL | 0.013 | 0.044 | 0.268 | 5.350 | transient_height |
| reverse-left | FAIL | 0.030 | 0.058 | 0.197 | 5.500 | transient_height |
| reverse-right | FAIL | 0.013 | 0.039 | 0.215 | 5.400 | transient_height |
| turn-left | FAIL | 0.091 | 0.095 | 0.280 | 4.900 | transient_height, active_attitude, active_height |
| turn-right | FAIL | 0.083 | 0.085 | 0.153 | 4.750 | transient_height, active_attitude, active_height |
| climb-forward | FAIL | 0.121 | 0.186 | 0.138 | 6.650 | transient_height, braking |
| descend-left | PASS | 0.021 | 0.085 | 0.316 | 4.900 | — |
| vertical-cycle | PASS | 0.024 | 0.051 | 0.000 | — | — |
| reverse-command | FAIL | 0.058 | 0.083 | 0.139 | 3.400 | transient_height, active_height |
| brake | FAIL | 0.141 | 0.129 | 0.309 | 6.350 | transient_height, active_height, braking |
| slalom | FAIL | 0.122 | 0.196 | 0.185 | 1.800 | transient_height, active_attitude, active_height, motion |
| gust | PASS | 0.014 | 0.082 | 0.263 | — | — |
| load-swing | PASS | 0.019 | 0.029 | 0.046 | — | — |
| recovery-diagonal | PASS | 0.008 | 0.047 | 0.258 | — | — |
| recovery-inverted | FAIL | 0.078 | 0.068 | 0.213 | — | transient_height |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/modular-6-fpv.pdf` et `traces/modular-6/fpv/`.
