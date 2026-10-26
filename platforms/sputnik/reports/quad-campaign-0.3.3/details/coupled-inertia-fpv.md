# coupled-inertia / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.008 | 0.000 | — | — |
| cold-hover | PASS | 0.002 | 0.007 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.011 | 0.000 | — | — |
| descend | PASS | 0.001 | 0.010 | 0.000 | — | — |
| forward | PASS | 0.002 | 0.041 | 0.189 | 4.600 | — |
| reverse | PASS | 0.014 | 0.023 | 0.164 | 4.550 | — |
| left | PASS | 0.017 | 0.027 | 0.243 | 3.650 | — |
| right | PASS | 0.007 | 0.029 | 0.379 | 3.700 | — |
| forward-left | PASS | 0.016 | 0.033 | 0.262 | 4.950 | — |
| forward-right | PASS | 0.009 | 0.033 | 0.174 | 4.800 | — |
| reverse-left | PASS | 0.001 | 0.025 | 0.188 | 4.750 | — |
| reverse-right | PASS | 0.001 | 0.019 | 0.178 | 4.850 | — |
| turn-left | PASS | 0.003 | 0.032 | 0.213 | 4.650 | — |
| turn-right | PASS | 0.015 | 0.031 | 0.170 | 4.650 | — |
| climb-forward | PASS | 0.007 | 0.031 | 0.239 | 5.100 | — |
| descend-left | PASS | 0.022 | 0.040 | 0.227 | 4.700 | — |
| vertical-cycle | PASS | 0.002 | 0.009 | 0.000 | — | — |
| reverse-command | PASS | 0.001 | 0.025 | 0.197 | 3.750 | — |
| brake | PASS | 0.002 | 0.041 | 0.189 | 4.600 | — |
| slalom | PASS | 0.013 | 0.032 | 0.441 | 4.400 | — |
| gust | PASS | 0.005 | 0.025 | 0.245 | — | — |
| load-swing | PASS | 0.001 | 0.036 | 0.211 | — | — |
| recovery-diagonal | PASS | 0.012 | 0.039 | 0.170 | — | — |
| recovery-inverted | PASS | 0.003 | 0.035 | 0.301 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/coupled-inertia-fpv.pdf` et `traces/coupled-inertia/fpv/`.
