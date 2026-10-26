# cross-plus / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.001 | 0.014 | 0.000 | — | — |
| cold-hover | PASS | 0.005 | 0.022 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.023 | 0.000 | — | — |
| descend | PASS | 0.000 | 0.044 | 0.000 | — | — |
| forward | PASS | 0.011 | 0.027 | 0.037 | 4.900 | — |
| reverse | PASS | 0.011 | 0.027 | 0.037 | 4.900 | — |
| left | PASS | 0.011 | 0.027 | 0.037 | 4.900 | — |
| right | PASS | 0.011 | 0.027 | 0.037 | 4.900 | — |
| forward-left | PASS | 0.001 | 0.020 | 0.009 | 4.650 | — |
| forward-right | PASS | 0.001 | 0.020 | 0.009 | 4.650 | — |
| reverse-left | PASS | 0.001 | 0.020 | 0.009 | 4.650 | — |
| reverse-right | PASS | 0.001 | 0.020 | 0.009 | 4.650 | — |
| turn-left | PASS | 0.001 | 0.018 | 0.014 | 4.600 | — |
| turn-right | PASS | 0.001 | 0.018 | 0.014 | 4.600 | — |
| climb-forward | PASS | 0.010 | 0.022 | 0.022 | 5.150 | — |
| descend-left | PASS | 0.007 | 0.048 | 0.078 | 4.200 | — |
| vertical-cycle | PASS | 0.005 | 0.020 | 0.000 | — | — |
| reverse-command | PASS | 0.023 | 0.097 | 1.115 | 4.200 | — |
| brake | PASS | 0.011 | 0.027 | 0.037 | 4.900 | — |
| slalom | FAIL | 0.006 | 0.079 | 0.762 | 4.500 | active_attitude, motion |
| gust | PASS | 0.053 | 0.190 | 0.796 | — | — |
| load-swing | PASS | 0.031 | 0.186 | 1.118 | — | — |
| recovery-diagonal | PASS | 0.008 | 0.186 | 0.723 | — | — |
| recovery-inverted | PASS | 0.096 | 0.111 | 0.791 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/cross-plus-fpv.pdf` et `traces/cross-plus/fpv/`.
