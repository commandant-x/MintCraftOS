# modular-24 / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.010 | 0.037 | 0.000 | — | — |
| cold-hover | PASS | 0.014 | 0.037 | 0.000 | — | — |
| climb | FAIL | 0.014 | 0.047 | 0.000 | — | transient_height |
| descend | PASS | 0.000 | 0.030 | 0.000 | — | — |
| forward | FAIL | 0.224 | 0.366 | 1.693 | 4.550 | active_height |
| reverse | FAIL | 0.224 | 0.366 | 1.693 | 4.550 | active_height |
| left | FAIL | 0.017 | 0.448 | 2.149 | 4.400 | active_height |
| right | FAIL | 0.017 | 0.448 | 2.149 | 4.400 | active_height |
| forward-left | FAIL | 0.370 | 0.403 | 2.716 | 4.700 | active_height |
| forward-right | FAIL | 0.370 | 0.403 | 2.716 | 4.700 | active_height |
| reverse-left | FAIL | 0.370 | 0.403 | 2.716 | 4.700 | active_height |
| reverse-right | FAIL | 0.370 | 0.403 | 2.716 | 4.700 | active_height |
| turn-left | FAIL | 0.125 | 0.274 | 1.608 | 4.800 | active_height |
| turn-right | FAIL | 0.125 | 0.274 | 1.608 | 4.800 | active_height |
| climb-forward | FAIL | 0.174 | 0.402 | 2.497 | 4.550 | transient_height |
| descend-left | FAIL | 0.016 | 0.345 | 1.108 | 4.400 | transient_height |
| vertical-cycle | FAIL | 0.028 | 0.043 | 0.000 | — | transient_height |
| reverse-command | FAIL | 0.020 | 0.059 | 0.232 | 3.750 | active_height |
| brake | FAIL | 0.224 | 0.366 | 1.693 | 4.550 | active_height |
| slalom | FAIL | 0.102 | 0.475 | 2.664 | 4.750 | active_height, motion |
| gust | PASS | 0.010 | 0.110 | 0.043 | — | — |
| load-swing | PASS | 0.035 | 0.623 | 1.712 | — | — |
| recovery-diagonal | PASS | 0.048 | 0.403 | 2.492 | — | — |
| recovery-inverted | FAIL | 0.088 | 0.132 | 0.069 | — | transient_height, recovery |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/modular-24-fpv.pdf` et `traces/modular-24/fpv/`.
