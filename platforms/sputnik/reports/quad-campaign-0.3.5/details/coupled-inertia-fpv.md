# coupled-inertia / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.008 | 0.000 | — | — |
| cold-hover | PASS | 0.001 | 0.007 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.011 | 0.000 | — | — |
| descend | PASS | 0.001 | 0.010 | 0.000 | — | — |
| forward | PASS | 0.006 | 0.031 | 0.258 | 4.500 | — |
| reverse | PASS | 0.001 | 0.029 | 0.312 | 4.500 | — |
| left | PASS | 0.002 | 0.030 | 0.304 | 4.400 | — |
| right | PASS | 0.003 | 0.026 | 0.380 | 3.650 | — |
| forward-left | PASS | 0.007 | 0.019 | 0.291 | 4.650 | — |
| forward-right | PASS | 0.021 | 0.031 | 0.180 | 4.650 | — |
| reverse-left | PASS | 0.003 | 0.025 | 0.231 | 4.650 | — |
| reverse-right | PASS | 0.017 | 0.027 | 0.223 | 4.550 | — |
| turn-left | PASS | 0.011 | 0.015 | 0.158 | 4.350 | — |
| turn-right | PASS | 0.010 | 0.017 | 0.193 | 4.400 | — |
| climb-forward | PASS | 0.005 | 0.026 | 0.246 | 5.100 | — |
| descend-left | PASS | 0.008 | 0.040 | 0.174 | 3.950 | — |
| vertical-cycle | PASS | 0.002 | 0.009 | 0.000 | — | — |
| reverse-command | PASS | 0.019 | 0.043 | 0.186 | 3.850 | — |
| brake | PASS | 0.006 | 0.031 | 0.258 | 4.500 | — |
| slalom | PASS | 0.013 | 0.026 | 0.176 | 4.250 | — |
| gust | PASS | 0.004 | 0.020 | 0.176 | — | — |
| load-swing | PASS | 0.014 | 0.026 | 0.281 | — | — |
| recovery-diagonal | PASS | 0.008 | 0.030 | 0.163 | — | — |
| recovery-inverted | PASS | 0.006 | 0.025 | 0.191 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/coupled-inertia-fpv.pdf` et `traces/coupled-inertia/fpv/`.
