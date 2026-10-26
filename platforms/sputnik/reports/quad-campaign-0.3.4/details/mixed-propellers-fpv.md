# mixed-propellers / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.055 | 0.175 | 0.855 | — | — |
| cold-hover | PASS | 0.078 | 0.195 | 0.521 | — | — |
| climb | PASS | 0.057 | 0.191 | 1.184 | — | — |
| descend | PASS | 0.092 | 0.201 | 0.966 | — | — |
| forward | PASS | 0.026 | 0.131 | 0.658 | 4.450 | — |
| reverse | FAIL | 0.081 | 0.153 | 0.698 | 3.900 | transient_tilt |
| left | PASS | 0.045 | 0.125 | 0.699 | 5.200 | — |
| right | FAIL | 0.036 | 0.175 | 0.655 | 4.700 | transient_tilt |
| forward-left | PASS | 0.093 | 0.224 | 1.692 | 4.500 | — |
| forward-right | PASS | 0.009 | 0.150 | 1.189 | 4.450 | — |
| reverse-left | PASS | 0.001 | 0.133 | 0.566 | 4.250 | — |
| reverse-right | FAIL | 0.049 | 0.170 | 0.839 | 6.200 | transient_tilt, braking |
| turn-left | PASS | 0.026 | 0.109 | 0.686 | 4.150 | — |
| turn-right | PASS | 0.052 | 0.097 | 0.634 | 3.850 | — |
| climb-forward | FAIL | 0.029 | 0.104 | 0.721 | 5.150 | transient_height |
| descend-left | PASS | 0.074 | 0.169 | 1.018 | 3.900 | — |
| vertical-cycle | PASS | 0.044 | 0.138 | 0.697 | — | — |
| reverse-command | PASS | 0.020 | 0.173 | 1.427 | 3.600 | — |
| brake | PASS | 0.026 | 0.131 | 0.658 | 4.450 | — |
| slalom | FAIL | 0.062 | 0.116 | 0.725 | 4.100 | motion |
| gust | PASS | 0.012 | 0.162 | 0.613 | — | — |
| load-swing | PASS | 0.040 | 0.100 | 2.003 | — | — |
| recovery-diagonal | PASS | 0.011 | 0.124 | 0.694 | — | — |
| recovery-inverted | FAIL | 0.026 | 0.170 | 0.702 | — | transient_height |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/mixed-propellers-fpv.pdf` et `traces/mixed-propellers/fpv/`.
