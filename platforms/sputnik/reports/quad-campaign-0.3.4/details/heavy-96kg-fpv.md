# heavy-96kg / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.001 | 0.004 | 0.000 | — | — |
| cold-hover | PASS | 0.002 | 0.004 | 0.000 | — | — |
| climb | PASS | 0.004 | 0.006 | 0.000 | — | — |
| descend | PASS | 0.001 | 0.013 | 0.000 | — | — |
| forward | PASS | 0.002 | 0.017 | 0.090 | 4.600 | — |
| reverse | PASS | 0.002 | 0.017 | 0.090 | 4.600 | — |
| left | PASS | 0.002 | 0.017 | 0.091 | 4.350 | — |
| right | PASS | 0.002 | 0.017 | 0.091 | 4.350 | — |
| forward-left | PASS | 0.002 | 0.013 | 0.102 | 4.700 | — |
| forward-right | PASS | 0.000 | 0.015 | 0.100 | 4.700 | — |
| reverse-left | PASS | 0.000 | 0.015 | 0.100 | 4.700 | — |
| reverse-right | PASS | 0.002 | 0.013 | 0.102 | 4.700 | — |
| turn-left | PASS | 0.001 | 0.015 | 0.091 | 4.250 | — |
| turn-right | PASS | 0.008 | 0.015 | 0.126 | 4.250 | — |
| climb-forward | PASS | 0.004 | 0.007 | 0.106 | 5.450 | — |
| descend-left | PASS | 0.006 | 0.022 | 0.159 | 4.300 | — |
| vertical-cycle | PASS | 0.001 | 0.004 | 0.000 | — | — |
| reverse-command | PASS | 0.000 | 0.015 | 0.102 | 4.150 | — |
| brake | PASS | 0.002 | 0.017 | 0.090 | 4.600 | — |
| slalom | PASS | 0.006 | 0.014 | 0.100 | 4.400 | — |
| gust | PASS | 0.003 | 0.013 | 0.086 | — | — |
| load-swing | PASS | 0.001 | 0.007 | 0.098 | — | — |
| recovery-diagonal | PASS | 0.001 | 0.016 | 0.108 | — | — |
| recovery-inverted | FAIL | 0.066 | 0.092 | 0.113 | — | transient_height |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/heavy-96kg-fpv.pdf` et `traces/heavy-96kg/fpv/`.
