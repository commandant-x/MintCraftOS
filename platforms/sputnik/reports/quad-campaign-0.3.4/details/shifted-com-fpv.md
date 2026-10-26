# shifted-com / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.026 | 0.107 | 0.226 | — | — |
| cold-hover | PASS | 0.015 | 0.107 | 0.245 | — | — |
| climb | PASS | 0.025 | 0.068 | 0.190 | — | — |
| descend | PASS | 0.013 | 0.103 | 0.283 | — | — |
| forward | PASS | 0.000 | 0.084 | 0.172 | 4.450 | — |
| reverse | PASS | 0.025 | 0.069 | 0.201 | 4.750 | — |
| left | PASS | 0.006 | 0.086 | 0.167 | 4.150 | — |
| right | PASS | 0.003 | 0.097 | 0.337 | 4.800 | — |
| forward-left | PASS | 0.018 | 0.064 | 0.254 | 4.600 | — |
| forward-right | PASS | 0.047 | 0.097 | 0.238 | 4.450 | — |
| reverse-left | PASS | 0.019 | 0.133 | 0.208 | 4.900 | — |
| reverse-right | PASS | 0.026 | 0.064 | 0.131 | 4.750 | — |
| turn-left | PASS | 0.019 | 0.078 | 0.199 | 3.700 | — |
| turn-right | PASS | 0.005 | 0.132 | 0.298 | 4.300 | — |
| climb-forward | PASS | 0.013 | 0.063 | 0.220 | 5.150 | — |
| descend-left | FAIL | 0.000 | 0.085 | 0.376 | 3.800 | transient_height |
| vertical-cycle | PASS | 0.030 | 0.077 | 0.216 | — | — |
| reverse-command | PASS | 0.009 | 0.087 | 0.144 | 4.200 | — |
| brake | PASS | 0.000 | 0.084 | 0.172 | 4.450 | — |
| slalom | FAIL | 0.011 | 0.100 | 0.237 | 4.150 | motion |
| gust | PASS | 0.047 | 0.092 | 0.232 | — | — |
| load-swing | PASS | 0.049 | 0.127 | 0.224 | — | — |
| recovery-diagonal | PASS | 0.034 | 0.078 | 0.186 | — | — |
| recovery-inverted | FAIL | 0.072 | 0.175 | 0.208 | — | transient_height |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/shifted-com-fpv.pdf` et `traces/shifted-com/fpv/`.
