# narrow / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.001 | 0.014 | 0.000 | — | — |
| cold-hover | PASS | 0.005 | 0.022 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.023 | 0.000 | — | — |
| descend | PASS | 0.000 | 0.044 | 0.000 | — | — |
| forward | PASS | 0.033 | 0.107 | 0.489 | 4.600 | — |
| reverse | PASS | 0.033 | 0.107 | 0.489 | 4.600 | — |
| left | PASS | 0.003 | 0.024 | 0.026 | 4.000 | — |
| right | PASS | 0.003 | 0.024 | 0.026 | 4.000 | — |
| forward-left | PASS | 0.015 | 0.052 | 0.019 | 4.700 | — |
| forward-right | PASS | 0.015 | 0.052 | 0.019 | 4.700 | — |
| reverse-left | PASS | 0.015 | 0.052 | 0.019 | 4.700 | — |
| reverse-right | PASS | 0.015 | 0.052 | 0.019 | 4.700 | — |
| turn-left | PASS | 0.010 | 0.065 | 0.693 | 4.700 | — |
| turn-right | PASS | 0.010 | 0.065 | 0.693 | 4.700 | — |
| climb-forward | PASS | 0.024 | 0.080 | 0.675 | 5.100 | — |
| descend-left | FAIL | 0.003 | 0.080 | 0.659 | 4.500 | transient_height |
| vertical-cycle | PASS | 0.005 | 0.020 | 0.000 | — | — |
| reverse-command | PASS | 0.014 | 0.176 | 1.271 | 3.800 | — |
| brake | PASS | 0.033 | 0.107 | 0.489 | 4.600 | — |
| slalom | FAIL | 0.030 | 0.144 | 0.866 | 4.400 | motion |
| gust | PASS | 0.021 | 0.100 | 0.630 | — | — |
| load-swing | PASS | 0.017 | 0.159 | 0.798 | — | — |
| recovery-diagonal | PASS | 0.058 | 0.154 | 1.876 | — | — |
| recovery-inverted | FAIL | 0.151 | 0.169 | 0.259 | — | transient_height |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/narrow-fpv.pdf` et `traces/narrow/fpv/`.
