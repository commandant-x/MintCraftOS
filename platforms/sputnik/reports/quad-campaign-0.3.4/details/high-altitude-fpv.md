# high-altitude / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.001 | 0.007 | 2.228 | — | — |
| cold-hover | PASS | 0.002 | 0.011 | 2.232 | — | — |
| climb | PASS | 0.002 | 0.010 | 2.218 | — | — |
| descend | PASS | 0.001 | 0.010 | 2.230 | — | — |
| forward | PASS | 0.000 | 0.006 | 2.211 | 4.500 | — |
| reverse | PASS | 0.005 | 0.009 | 2.217 | 5.100 | — |
| left | PASS | 0.006 | 0.011 | 2.219 | 4.350 | — |
| right | PASS | 0.004 | 0.013 | 2.221 | 5.400 | — |
| forward-left | PASS | 0.002 | 0.009 | 2.223 | 4.300 | — |
| forward-right | PASS | 0.005 | 0.008 | 2.239 | 5.150 | — |
| reverse-left | PASS | 0.003 | 0.011 | 2.242 | 4.550 | — |
| reverse-right | PASS | 0.003 | 0.014 | 2.229 | 5.550 | — |
| turn-left | PASS | 0.003 | 0.006 | 2.213 | 4.100 | — |
| turn-right | PASS | 0.002 | 0.012 | 2.223 | 5.100 | — |
| climb-forward | PASS | 0.001 | 0.014 | 2.213 | 5.150 | — |
| descend-left | PASS | 0.009 | 0.014 | 2.215 | 3.550 | — |
| vertical-cycle | PASS | 0.006 | 0.008 | 2.223 | — | — |
| reverse-command | PASS | 0.004 | 0.009 | 2.212 | 4.600 | — |
| brake | PASS | 0.000 | 0.006 | 2.211 | 4.500 | — |
| slalom | FAIL | 0.002 | 0.015 | 2.222 | 4.600 | motion |
| gust | PASS | 0.002 | 0.007 | 2.235 | — | — |
| load-swing | PASS | 0.020 | 0.024 | 2.474 | — | — |
| recovery-diagonal | PASS | 0.001 | 0.005 | 2.227 | — | — |
| recovery-inverted | FAIL | 0.035 | 0.045 | 2.230 | — | transient_height |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/high-altitude-fpv.pdf` et `traces/high-altitude/fpv/`.
