# shifted-com / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.011 | 0.085 | 0.209 | — | — |
| cold-hover | PASS | 0.031 | 0.074 | 0.205 | — | — |
| climb | PASS | 0.003 | 0.040 | 0.214 | — | — |
| descend | PASS | 0.004 | 0.076 | 0.215 | — | — |
| forward | PASS | 0.015 | 0.096 | 0.237 | 4.550 | — |
| reverse | PASS | 0.030 | 0.111 | 0.190 | 4.750 | — |
| left | PASS | 0.017 | 0.058 | 0.168 | 4.250 | — |
| right | PASS | 0.004 | 0.089 | 0.262 | 4.750 | — |
| forward-left | PASS | 0.005 | 0.080 | 0.233 | 4.650 | — |
| forward-right | PASS | 0.007 | 0.087 | 0.234 | 4.450 | — |
| reverse-left | PASS | 0.015 | 0.096 | 0.216 | 4.900 | — |
| reverse-right | PASS | 0.023 | 0.125 | 0.304 | 4.700 | — |
| turn-left | PASS | 0.002 | 0.068 | 0.212 | 3.850 | — |
| turn-right | PASS | 0.039 | 0.073 | 0.232 | 4.300 | — |
| climb-forward | PASS | 0.030 | 0.084 | 0.174 | 5.100 | — |
| descend-left | FAIL | 0.052 | 0.119 | 0.342 | 4.100 | transient_height |
| vertical-cycle | PASS | 0.002 | 0.054 | 0.147 | — | — |
| reverse-command | PASS | 0.003 | 0.095 | 0.177 | 4.200 | — |
| brake | PASS | 0.015 | 0.096 | 0.237 | 4.550 | — |
| slalom | FAIL | 0.014 | 0.102 | 0.252 | 4.150 | motion |
| gust | PASS | 0.002 | 0.081 | 0.232 | — | — |
| load-swing | PASS | 0.008 | 0.089 | 0.207 | — | — |
| recovery-diagonal | PASS | 0.028 | 0.071 | 0.198 | — | — |
| recovery-inverted | PASS | 0.041 | 0.068 | 0.199 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/shifted-com-fpv.pdf` et `traces/shifted-com/fpv/`.
