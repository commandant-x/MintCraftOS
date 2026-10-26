# weak-one-rotor / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.005 | 0.144 | 0.517 | — | — |
| cold-hover | PASS | 0.030 | 0.088 | 0.417 | — | — |
| climb | FAIL | 0.015 | 0.052 | 0.302 | — | transient_height |
| descend | PASS | 0.074 | 0.231 | 1.014 | — | — |
| forward | PASS | 0.017 | 0.122 | 0.591 | 4.950 | — |
| reverse | PASS | 0.052 | 0.149 | 0.881 | 4.600 | — |
| left | PASS | 0.055 | 0.135 | 1.038 | 5.050 | — |
| right | PASS | 0.075 | 0.182 | 0.958 | 4.600 | — |
| forward-left | PASS | 0.030 | 0.149 | 0.776 | 5.250 | — |
| forward-right | PASS | 0.024 | 0.125 | 0.619 | 4.800 | — |
| reverse-left | PASS | 0.060 | 0.172 | 1.045 | 4.950 | — |
| reverse-right | PASS | 0.070 | 0.164 | 0.859 | 4.500 | — |
| turn-left | PASS | 0.035 | 0.138 | 1.000 | 4.750 | — |
| turn-right | PASS | 0.002 | 0.116 | 1.010 | 4.550 | — |
| climb-forward | PASS | 0.015 | 0.087 | 0.570 | 5.350 | — |
| descend-left | FAIL | 0.029 | 0.252 | 1.437 | 5.350 | transient_height |
| vertical-cycle | FAIL | 0.030 | 0.131 | 0.797 | — | transient_height |
| reverse-command | PASS | 0.025 | 0.255 | 1.125 | 3.750 | — |
| brake | PASS | 0.017 | 0.122 | 0.591 | 4.950 | — |
| slalom | FAIL | 0.040 | 0.159 | 1.126 | 4.700 | motion |
| gust | PASS | 0.006 | 0.236 | 1.112 | — | — |
| load-swing | PASS | 0.006 | 0.087 | 0.367 | — | — |
| recovery-diagonal | PASS | 0.035 | 0.121 | 0.664 | — | — |
| recovery-inverted | PASS | 0.027 | 0.323 | 1.238 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/weak-one-rotor-fpv.pdf` et `traces/weak-one-rotor/fpv/`.
