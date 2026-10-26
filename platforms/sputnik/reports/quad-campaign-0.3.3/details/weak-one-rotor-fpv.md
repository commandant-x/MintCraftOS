# weak-one-rotor / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.039 | 0.189 | 0.853 | — | — |
| cold-hover | PASS | 0.013 | 0.111 | 0.479 | — | — |
| climb | FAIL | 0.030 | 0.117 | 0.455 | — | transient_height |
| descend | PASS | 0.061 | 0.134 | 0.702 | — | — |
| forward | PASS | 0.004 | 0.121 | 0.601 | 5.050 | — |
| reverse | PASS | 0.062 | 0.132 | 0.756 | 4.500 | — |
| left | PASS | 0.072 | 0.131 | 0.775 | 5.150 | — |
| right | PASS | 0.045 | 0.102 | 0.850 | 4.550 | — |
| forward-left | PASS | 0.027 | 0.215 | 1.156 | 5.100 | — |
| forward-right | PASS | 0.019 | 0.161 | 0.818 | 4.750 | — |
| reverse-left | PASS | 0.045 | 0.167 | 1.026 | 4.900 | — |
| reverse-right | PASS | 0.022 | 0.122 | 0.709 | 4.300 | — |
| turn-left | PASS | 0.048 | 0.142 | 0.870 | 4.850 | — |
| turn-right | PASS | 0.041 | 0.162 | 0.892 | 4.550 | — |
| climb-forward | PASS | 0.016 | 0.075 | 0.386 | 5.350 | — |
| descend-left | FAIL | 0.023 | 0.161 | 1.033 | 4.900 | transient_height |
| vertical-cycle | FAIL | 0.083 | 0.177 | 0.944 | — | transient_height |
| reverse-command | PASS | 0.084 | 0.160 | 0.470 | 3.700 | — |
| brake | PASS | 0.004 | 0.121 | 0.601 | 5.050 | — |
| slalom | FAIL | 0.014 | 0.113 | 1.105 | 4.800 | motion |
| gust | PASS | 0.002 | 0.125 | 0.788 | — | — |
| load-swing | PASS | 0.029 | 0.055 | 0.396 | — | — |
| recovery-diagonal | PASS | 0.027 | 0.139 | 1.103 | — | — |
| recovery-inverted | PASS | 0.071 | 0.170 | 0.982 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/weak-one-rotor-fpv.pdf` et `traces/weak-one-rotor/fpv/`.
