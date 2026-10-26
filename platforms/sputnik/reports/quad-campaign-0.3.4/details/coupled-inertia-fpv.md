# coupled-inertia / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.008 | 0.000 | — | — |
| cold-hover | PASS | 0.002 | 0.007 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.011 | 0.000 | — | — |
| descend | PASS | 0.001 | 0.010 | 0.000 | — | — |
| forward | PASS | 0.009 | 0.023 | 0.235 | 4.500 | — |
| reverse | PASS | 0.012 | 0.016 | 0.236 | 4.500 | — |
| left | PASS | 0.000 | 0.016 | 0.172 | 3.750 | — |
| right | PASS | 0.008 | 0.021 | 0.371 | 3.800 | — |
| forward-left | PASS | 0.015 | 0.021 | 0.182 | 4.550 | — |
| forward-right | PASS | 0.021 | 0.029 | 0.212 | 4.600 | — |
| reverse-left | PASS | 0.017 | 0.047 | 0.189 | 4.600 | — |
| reverse-right | PASS | 0.004 | 0.032 | 0.331 | 4.500 | — |
| turn-left | PASS | 0.011 | 0.025 | 0.275 | 4.350 | — |
| turn-right | PASS | 0.017 | 0.032 | 0.185 | 4.350 | — |
| climb-forward | PASS | 0.008 | 0.013 | 0.346 | 5.150 | — |
| descend-left | PASS | 0.003 | 0.046 | 0.176 | 4.100 | — |
| vertical-cycle | PASS | 0.002 | 0.009 | 0.000 | — | — |
| reverse-command | PASS | 0.005 | 0.027 | 0.194 | 3.800 | — |
| brake | PASS | 0.009 | 0.023 | 0.235 | 4.500 | — |
| slalom | PASS | 0.021 | 0.031 | 0.243 | 4.200 | — |
| gust | PASS | 0.010 | 0.042 | 0.168 | — | — |
| load-swing | PASS | 0.003 | 0.035 | 0.210 | — | — |
| recovery-diagonal | PASS | 0.013 | 0.030 | 0.305 | — | — |
| recovery-inverted | PASS | 0.001 | 0.025 | 0.230 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/coupled-inertia-fpv.pdf` et `traces/coupled-inertia/fpv/`.
