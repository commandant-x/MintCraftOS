# modular-6 / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.001 | 0.026 | 0.000 | — | — |
| cold-hover | PASS | 0.001 | 0.026 | 0.000 | — | — |
| climb | PASS | 0.003 | 0.008 | 0.000 | — | — |
| descend | PASS | 0.001 | 0.007 | 0.000 | — | — |
| forward | PASS | 0.006 | 0.025 | 0.127 | 4.500 | — |
| reverse | PASS | 0.006 | 0.025 | 0.127 | 4.500 | — |
| left | PASS | 0.014 | 0.022 | 0.120 | 4.350 | — |
| right | PASS | 0.014 | 0.022 | 0.120 | 4.350 | — |
| forward-left | PASS | 0.007 | 0.026 | 0.157 | 4.650 | — |
| forward-right | PASS | 0.001 | 0.018 | 0.111 | 4.650 | — |
| reverse-left | PASS | 0.001 | 0.018 | 0.111 | 4.650 | — |
| reverse-right | PASS | 0.007 | 0.026 | 0.157 | 4.650 | — |
| turn-left | PASS | 0.009 | 0.024 | 0.112 | 4.200 | — |
| turn-right | PASS | 0.001 | 0.023 | 0.126 | 4.200 | — |
| climb-forward | PASS | 0.004 | 0.014 | 0.089 | 5.150 | — |
| descend-left | PASS | 0.004 | 0.011 | 0.121 | 4.200 | — |
| vertical-cycle | PASS | 0.010 | 0.022 | 0.000 | — | — |
| reverse-command | PASS | 0.004 | 0.023 | 0.111 | 3.950 | — |
| brake | PASS | 0.006 | 0.025 | 0.127 | 4.500 | — |
| slalom | PASS | 0.002 | 0.024 | 0.123 | 4.250 | — |
| gust | PASS | 0.001 | 0.024 | 0.157 | — | — |
| load-swing | PASS | 0.004 | 0.012 | 0.149 | — | — |
| recovery-diagonal | PASS | 0.006 | 0.024 | 0.134 | — | — |
| recovery-inverted | FAIL | 0.060 | 0.072 | 0.100 | — | transient_height |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/modular-6-fpv.pdf` et `traces/modular-6/fpv/`.
