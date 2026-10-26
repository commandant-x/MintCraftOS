# cross-plus / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.008 | 0.000 | — | — |
| cold-hover | PASS | 0.002 | 0.007 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.011 | 0.000 | — | — |
| descend | PASS | 0.001 | 0.010 | 0.000 | — | — |
| forward | PASS | 0.005 | 0.016 | 0.203 | 4.400 | — |
| reverse | PASS | 0.005 | 0.016 | 0.203 | 4.400 | — |
| left | PASS | 0.009 | 0.015 | 0.229 | 4.350 | — |
| right | PASS | 0.009 | 0.015 | 0.229 | 4.350 | — |
| forward-left | PASS | 0.017 | 0.025 | 0.221 | 4.750 | — |
| forward-right | PASS | 0.017 | 0.025 | 0.221 | 4.750 | — |
| reverse-left | PASS | 0.017 | 0.025 | 0.221 | 4.750 | — |
| reverse-right | PASS | 0.017 | 0.025 | 0.221 | 4.750 | — |
| turn-left | PASS | 0.008 | 0.029 | 0.280 | 4.450 | — |
| turn-right | PASS | 0.008 | 0.029 | 0.280 | 4.450 | — |
| climb-forward | PASS | 0.005 | 0.015 | 0.226 | 5.150 | — |
| descend-left | PASS | 0.004 | 0.026 | 0.227 | 4.100 | — |
| vertical-cycle | PASS | 0.002 | 0.009 | 0.000 | — | — |
| reverse-command | PASS | 0.002 | 0.021 | 0.157 | 3.850 | — |
| brake | PASS | 0.005 | 0.016 | 0.203 | 4.400 | — |
| slalom | FAIL | 0.016 | 0.022 | 0.224 | 4.500 | motion |
| gust | PASS | 0.004 | 0.016 | 0.263 | — | — |
| load-swing | PASS | 0.008 | 0.029 | 0.187 | — | — |
| recovery-diagonal | PASS | 0.011 | 0.026 | 0.328 | — | — |
| recovery-inverted | PASS | 0.004 | 0.020 | 0.207 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/cross-plus-fpv.pdf` et `traces/cross-plus/fpv/`.
