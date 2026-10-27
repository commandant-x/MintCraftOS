# high-altitude / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.000 | 0.009 | 2.213 | — | — |
| cold-hover | PASS | 0.000 | 0.009 | 2.242 | — | — |
| climb | PASS | 0.004 | 0.010 | 2.209 | — | — |
| descend | PASS | 0.002 | 0.020 | 2.215 | — | — |
| forward | PASS | 0.000 | 0.011 | 2.202 | 4.550 | — |
| reverse | PASS | 0.006 | 0.007 | 2.210 | 5.100 | — |
| left | PASS | 0.005 | 0.010 | 2.224 | 4.050 | — |
| right | PASS | 0.003 | 0.011 | 2.213 | 5.400 | — |
| forward-left | PASS | 0.003 | 0.010 | 2.202 | 4.150 | — |
| forward-right | PASS | 0.000 | 0.011 | 2.204 | 5.200 | — |
| reverse-left | PASS | 0.003 | 0.011 | 2.230 | 4.550 | — |
| reverse-right | PASS | 0.003 | 0.014 | 2.218 | 5.550 | — |
| turn-left | PASS | 0.005 | 0.008 | 2.216 | 4.000 | — |
| turn-right | PASS | 0.003 | 0.011 | 2.215 | 5.150 | — |
| climb-forward | PASS | 0.004 | 0.008 | 2.229 | 5.350 | — |
| descend-left | PASS | 0.009 | 0.013 | 2.217 | 3.500 | — |
| vertical-cycle | FAIL | 0.001 | 0.009 | 2.219 | — | active_attitude |
| reverse-command | PASS | 0.003 | 0.009 | 2.220 | 4.650 | — |
| brake | PASS | 0.000 | 0.011 | 2.202 | 4.550 | — |
| slalom | FAIL | 0.005 | 0.008 | 2.254 | 4.600 | motion |
| gust | PASS | 0.001 | 0.010 | 2.214 | — | — |
| load-swing | PASS | 0.007 | 0.008 | 1.611 | — | — |
| recovery-diagonal | PASS | 0.001 | 0.010 | 2.207 | — | — |
| recovery-inverted | FAIL | 0.032 | 0.038 | 2.216 | — | transient_height |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/high-altitude-fpv.pdf` et `traces/high-altitude/fpv/`.
