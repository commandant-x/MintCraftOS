# narrow / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.008 | 0.000 | — | — |
| cold-hover | PASS | 0.002 | 0.007 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.011 | 0.000 | — | — |
| descend | PASS | 0.001 | 0.010 | 0.000 | — | — |
| forward | PASS | 0.008 | 0.029 | 0.241 | 4.600 | — |
| reverse | PASS | 0.008 | 0.029 | 0.241 | 4.600 | — |
| left | FAIL | 0.011 | 0.024 | 0.410 | 3.900 | transient_tilt |
| right | FAIL | 0.011 | 0.024 | 0.410 | 3.900 | transient_tilt |
| forward-left | PASS | 0.002 | 0.031 | 0.210 | 4.800 | — |
| forward-right | PASS | 0.020 | 0.024 | 0.218 | 4.750 | — |
| reverse-left | PASS | 0.020 | 0.024 | 0.218 | 4.750 | — |
| reverse-right | PASS | 0.002 | 0.031 | 0.210 | 4.800 | — |
| turn-left | PASS | 0.020 | 0.037 | 0.280 | 4.750 | — |
| turn-right | PASS | 0.017 | 0.016 | 0.362 | 4.600 | — |
| climb-forward | PASS | 0.013 | 0.033 | 0.225 | 5.150 | — |
| descend-left | FAIL | 0.009 | 0.028 | 0.265 | 4.350 | transient_height |
| vertical-cycle | PASS | 0.002 | 0.009 | 0.000 | — | — |
| reverse-command | PASS | 0.019 | 0.023 | 0.330 | 3.800 | — |
| brake | PASS | 0.008 | 0.029 | 0.241 | 4.600 | — |
| slalom | FAIL | 0.001 | 0.020 | 0.254 | 4.300 | motion |
| gust | PASS | 0.006 | 0.037 | 0.210 | — | — |
| load-swing | PASS | 0.012 | 0.032 | 0.228 | — | — |
| recovery-diagonal | PASS | 0.008 | 0.053 | 0.312 | — | — |
| recovery-inverted | FAIL | 0.120 | 0.146 | 0.300 | — | transient_height |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/narrow-fpv.pdf` et `traces/narrow/fpv/`.
