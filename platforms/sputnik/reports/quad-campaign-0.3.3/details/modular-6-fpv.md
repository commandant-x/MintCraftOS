# modular-6 / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.001 | 0.026 | 0.000 | — | — |
| cold-hover | PASS | 0.008 | 0.026 | 0.000 | — | — |
| climb | PASS | 0.003 | 0.008 | 0.000 | — | — |
| descend | PASS | 0.001 | 0.007 | 0.000 | — | — |
| forward | PASS | 0.008 | 0.021 | 0.116 | 4.500 | — |
| reverse | PASS | 0.008 | 0.021 | 0.116 | 4.500 | — |
| left | PASS | 0.004 | 0.021 | 0.115 | 4.350 | — |
| right | PASS | 0.004 | 0.021 | 0.115 | 4.350 | — |
| forward-left | PASS | 0.009 | 0.024 | 0.149 | 4.700 | — |
| forward-right | PASS | 0.011 | 0.020 | 0.101 | 4.700 | — |
| reverse-left | PASS | 0.011 | 0.020 | 0.101 | 4.700 | — |
| reverse-right | PASS | 0.009 | 0.024 | 0.149 | 4.700 | — |
| turn-left | PASS | 0.005 | 0.022 | 0.137 | 4.400 | — |
| turn-right | PASS | 0.006 | 0.020 | 0.131 | 4.400 | — |
| climb-forward | PASS | 0.005 | 0.013 | 0.101 | 5.200 | — |
| descend-left | PASS | 0.001 | 0.011 | 0.137 | 4.450 | — |
| vertical-cycle | PASS | 0.010 | 0.022 | 0.000 | — | — |
| reverse-command | PASS | 0.002 | 0.028 | 0.119 | 3.900 | — |
| brake | PASS | 0.008 | 0.021 | 0.116 | 4.500 | — |
| slalom | PASS | 0.003 | 0.012 | 0.107 | 4.500 | — |
| gust | PASS | 0.001 | 0.027 | 0.120 | — | — |
| load-swing | PASS | 0.006 | 0.012 | 0.135 | — | — |
| recovery-diagonal | PASS | 0.002 | 0.023 | 0.110 | — | — |
| recovery-inverted | FAIL | 0.057 | 0.086 | 0.107 | — | transient_height |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/modular-6-fpv.pdf` et `traces/modular-6/fpv/`.
