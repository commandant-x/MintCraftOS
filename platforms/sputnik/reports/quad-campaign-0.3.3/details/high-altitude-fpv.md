# high-altitude / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.004 | 0.011 | 2.240 | — | — |
| cold-hover | PASS | 0.000 | 0.009 | 2.236 | — | — |
| climb | PASS | 0.000 | 0.011 | 2.240 | — | — |
| descend | PASS | 0.005 | 0.015 | 2.236 | — | — |
| forward | PASS | 0.004 | 0.006 | 2.232 | 4.500 | — |
| reverse | PASS | 0.003 | 0.015 | 2.217 | 4.950 | — |
| left | PASS | 0.003 | 0.007 | 2.215 | 4.300 | — |
| right | PASS | 0.004 | 0.007 | 2.211 | 5.200 | — |
| forward-left | PASS | 0.002 | 0.009 | 2.214 | 4.400 | — |
| forward-right | PASS | 0.002 | 0.021 | 2.234 | 5.200 | — |
| reverse-left | PASS | 0.001 | 0.009 | 2.214 | 4.800 | — |
| reverse-right | PASS | 0.000 | 0.010 | 2.221 | 5.500 | — |
| turn-left | PASS | 0.001 | 0.009 | 2.231 | 4.200 | — |
| turn-right | PASS | 0.000 | 0.012 | 2.227 | 5.000 | — |
| climb-forward | PASS | 0.004 | 0.008 | 2.206 | 5.100 | — |
| descend-left | PASS | 0.010 | 0.010 | 2.225 | 4.100 | — |
| vertical-cycle | PASS | 0.001 | 0.008 | 2.234 | — | — |
| reverse-command | PASS | 0.002 | 0.009 | 2.214 | 4.550 | — |
| brake | PASS | 0.004 | 0.006 | 2.232 | 4.500 | — |
| slalom | FAIL | 0.001 | 0.012 | 2.219 | 4.850 | active_attitude, motion |
| gust | PASS | 0.003 | 0.010 | 2.222 | — | — |
| load-swing | PASS | 0.006 | 0.016 | 2.505 | — | — |
| recovery-diagonal | PASS | 0.001 | 0.007 | 2.228 | — | — |
| recovery-inverted | FAIL | 0.043 | 0.051 | 2.208 | — | transient_height |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/high-altitude-fpv.pdf` et `traces/high-altitude/fpv/`.
