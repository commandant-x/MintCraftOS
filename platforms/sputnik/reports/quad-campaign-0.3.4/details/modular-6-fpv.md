# modular-6 / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.001 | 0.026 | 0.000 | — | — |
| cold-hover | PASS | 0.008 | 0.026 | 0.000 | — | — |
| climb | PASS | 0.003 | 0.008 | 0.000 | — | — |
| descend | PASS | 0.001 | 0.007 | 0.000 | — | — |
| forward | PASS | 0.004 | 0.025 | 0.114 | 4.550 | — |
| reverse | PASS | 0.004 | 0.025 | 0.114 | 4.550 | — |
| left | PASS | 0.002 | 0.016 | 0.103 | 4.350 | — |
| right | PASS | 0.002 | 0.016 | 0.103 | 4.350 | — |
| forward-left | PASS | 0.002 | 0.025 | 0.119 | 4.650 | — |
| forward-right | PASS | 0.009 | 0.027 | 0.127 | 4.650 | — |
| reverse-left | PASS | 0.009 | 0.027 | 0.127 | 4.650 | — |
| reverse-right | PASS | 0.002 | 0.025 | 0.119 | 4.650 | — |
| turn-left | PASS | 0.004 | 0.022 | 0.108 | 4.200 | — |
| turn-right | PASS | 0.006 | 0.022 | 0.089 | 4.200 | — |
| climb-forward | PASS | 0.000 | 0.015 | 0.084 | 5.150 | — |
| descend-left | PASS | 0.007 | 0.015 | 0.160 | 4.200 | — |
| vertical-cycle | PASS | 0.010 | 0.022 | 0.000 | — | — |
| reverse-command | PASS | 0.007 | 0.022 | 0.115 | 3.950 | — |
| brake | PASS | 0.004 | 0.025 | 0.114 | 4.550 | — |
| slalom | PASS | 0.004 | 0.022 | 0.098 | 4.250 | — |
| gust | PASS | 0.011 | 0.023 | 0.133 | — | — |
| load-swing | PASS | 0.012 | 0.015 | 0.091 | — | — |
| recovery-diagonal | PASS | 0.007 | 0.021 | 0.108 | — | — |
| recovery-inverted | FAIL | 0.061 | 0.071 | 0.127 | — | transient_height |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/modular-6-fpv.pdf` et `traces/modular-6/fpv/`.
