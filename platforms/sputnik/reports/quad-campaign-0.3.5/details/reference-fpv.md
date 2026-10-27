# reference / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.002 | 0.008 | 0.000 | — | — |
| cold-hover | PASS | 0.001 | 0.007 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.011 | 0.000 | — | — |
| descend | PASS | 0.001 | 0.010 | 0.000 | — | — |
| forward | PASS | 0.003 | 0.021 | 0.206 | 4.550 | — |
| reverse | PASS | 0.003 | 0.021 | 0.206 | 4.550 | — |
| left | PASS | 0.006 | 0.019 | 0.226 | 3.700 | — |
| right | PASS | 0.006 | 0.019 | 0.226 | 3.700 | — |
| forward-left | PASS | 0.016 | 0.024 | 0.334 | 4.700 | — |
| forward-right | PASS | 0.003 | 0.036 | 0.317 | 4.700 | — |
| reverse-left | PASS | 0.003 | 0.036 | 0.317 | 4.700 | — |
| reverse-right | PASS | 0.016 | 0.024 | 0.334 | 4.700 | — |
| turn-left | PASS | 0.001 | 0.023 | 0.243 | 4.300 | — |
| turn-right | PASS | 0.016 | 0.043 | 0.241 | 4.300 | — |
| climb-forward | PASS | 0.020 | 0.035 | 0.399 | 5.100 | — |
| descend-left | PASS | 0.011 | 0.042 | 0.418 | 3.900 | — |
| vertical-cycle | PASS | 0.002 | 0.009 | 0.000 | — | — |
| reverse-command | PASS | 0.008 | 0.030 | 0.196 | 3.750 | — |
| brake | PASS | 0.003 | 0.021 | 0.206 | 4.550 | — |
| slalom | PASS | 0.003 | 0.021 | 0.216 | 4.250 | — |
| gust | PASS | 0.003 | 0.025 | 0.324 | — | — |
| load-swing | PASS | 0.004 | 0.032 | 0.374 | — | — |
| recovery-diagonal | PASS | 0.008 | 0.023 | 0.255 | — | — |
| recovery-inverted | PASS | 0.012 | 0.039 | 0.165 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/reference-fpv.pdf` et `traces/reference/fpv/`.
