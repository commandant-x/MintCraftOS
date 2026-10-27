# weak-one-rotor / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.098 | 0.307 | 1.143 | — | — |
| cold-hover | PASS | 0.091 | 0.255 | 1.641 | — | — |
| climb | PASS | 0.081 | 0.197 | 1.012 | — | — |
| descend | PASS | 0.064 | 0.175 | 1.074 | — | — |
| forward | PASS | 0.016 | 0.148 | 0.530 | 4.700 | — |
| reverse | PASS | 0.022 | 0.301 | 1.062 | 4.650 | — |
| left | PASS | 0.116 | 0.197 | 0.831 | 4.750 | — |
| right | PASS | 0.076 | 0.125 | 0.772 | 3.950 | — |
| forward-left | PASS | 0.092 | 0.167 | 0.771 | 4.850 | — |
| forward-right | PASS | 0.034 | 0.173 | 0.750 | 4.650 | — |
| reverse-left | PASS | 0.144 | 0.209 | 0.818 | 4.550 | — |
| reverse-right | PASS | 0.017 | 0.161 | 0.695 | 4.600 | — |
| turn-left | PASS | 0.077 | 0.188 | 0.753 | 4.450 | — |
| turn-right | PASS | 0.010 | 0.281 | 1.075 | 4.400 | — |
| climb-forward | PASS | 0.034 | 0.087 | 0.801 | 5.300 | — |
| descend-left | PASS | 0.001 | 0.194 | 1.340 | 4.450 | — |
| vertical-cycle | PASS | 0.054 | 0.242 | 0.900 | — | — |
| reverse-command | PASS | 0.015 | 0.252 | 1.337 | 4.100 | — |
| brake | PASS | 0.016 | 0.148 | 0.530 | 4.700 | — |
| slalom | FAIL | 0.003 | 0.112 | 0.533 | 4.400 | motion |
| gust | PASS | 0.072 | 0.160 | 0.799 | — | — |
| load-swing | PASS | 0.018 | 0.037 | 0.282 | — | — |
| recovery-diagonal | PASS | 0.022 | 0.103 | 0.596 | — | — |
| recovery-inverted | FAIL | 0.138 | 0.308 | 1.462 | — | transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/weak-one-rotor-fpv.pdf` et `traces/weak-one-rotor/fpv/`.
