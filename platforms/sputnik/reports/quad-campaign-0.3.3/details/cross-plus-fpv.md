# cross-plus / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.008 | 0.000 | — | — |
| cold-hover | PASS | 0.002 | 0.007 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.011 | 0.000 | — | — |
| descend | PASS | 0.001 | 0.010 | 0.000 | — | — |
| forward | PASS | 0.008 | 0.010 | 0.183 | 4.950 | — |
| reverse | PASS | 0.008 | 0.010 | 0.183 | 4.950 | — |
| left | PASS | 0.008 | 0.014 | 0.019 | 4.900 | — |
| right | PASS | 0.008 | 0.014 | 0.019 | 4.900 | — |
| forward-left | PASS | 0.006 | 0.020 | 0.282 | 4.750 | — |
| forward-right | PASS | 0.006 | 0.020 | 0.282 | 4.750 | — |
| reverse-left | PASS | 0.006 | 0.020 | 0.282 | 4.750 | — |
| reverse-right | PASS | 0.006 | 0.020 | 0.282 | 4.750 | — |
| turn-left | PASS | 0.003 | 0.029 | 0.285 | 4.600 | — |
| turn-right | PASS | 0.003 | 0.029 | 0.285 | 4.600 | — |
| climb-forward | PASS | 0.001 | 0.020 | 0.280 | 5.150 | — |
| descend-left | PASS | 0.012 | 0.034 | 0.407 | 4.200 | — |
| vertical-cycle | PASS | 0.002 | 0.009 | 0.000 | — | — |
| reverse-command | PASS | 0.006 | 0.019 | 0.166 | 4.150 | — |
| brake | PASS | 0.008 | 0.010 | 0.183 | 4.950 | — |
| slalom | FAIL | 0.003 | 0.023 | 0.250 | 4.550 | active_attitude, motion |
| gust | PASS | 0.007 | 0.026 | 0.228 | — | — |
| load-swing | PASS | 0.000 | 0.025 | 0.165 | — | — |
| recovery-diagonal | PASS | 0.001 | 0.018 | 0.228 | — | — |
| recovery-inverted | PASS | 0.005 | 0.012 | 0.115 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/cross-plus-fpv.pdf` et `traces/cross-plus/fpv/`.
