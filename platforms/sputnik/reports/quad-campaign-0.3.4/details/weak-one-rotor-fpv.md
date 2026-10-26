# weak-one-rotor / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.057 | 0.238 | 1.354 | — | — |
| cold-hover | PASS | 0.017 | 0.132 | 0.543 | — | — |
| climb | FAIL | 0.013 | 0.125 | 0.943 | — | transient_height |
| descend | PASS | 0.100 | 0.232 | 1.245 | — | — |
| forward | PASS | 0.053 | 0.098 | 0.558 | 4.700 | — |
| reverse | PASS | 0.091 | 0.270 | 1.143 | 4.700 | — |
| left | PASS | 0.015 | 0.096 | 0.396 | 4.500 | — |
| right | PASS | 0.004 | 0.130 | 0.601 | 4.150 | — |
| forward-left | PASS | 0.053 | 0.232 | 1.214 | 4.750 | — |
| forward-right | PASS | 0.054 | 0.287 | 1.449 | 4.750 | — |
| reverse-left | PASS | 0.085 | 0.231 | 0.745 | 4.450 | — |
| reverse-right | PASS | 0.040 | 0.177 | 0.690 | 4.800 | — |
| turn-left | PASS | 0.010 | 0.187 | 1.460 | 4.550 | — |
| turn-right | PASS | 0.056 | 0.164 | 0.619 | 4.500 | — |
| climb-forward | PASS | 0.079 | 0.170 | 0.837 | 5.150 | — |
| descend-left | FAIL | 0.004 | 0.291 | 1.315 | 4.250 | transient_height |
| vertical-cycle | FAIL | 0.007 | 0.244 | 1.246 | — | transient_height |
| reverse-command | PASS | 0.120 | 0.190 | 0.708 | 3.900 | — |
| brake | PASS | 0.053 | 0.098 | 0.558 | 4.700 | — |
| slalom | FAIL | 0.063 | 0.158 | 1.051 | 4.400 | motion |
| gust | PASS | 0.066 | 0.192 | 1.125 | — | — |
| load-swing | PASS | 0.053 | 0.121 | 0.313 | — | — |
| recovery-diagonal | PASS | 0.105 | 0.244 | 1.440 | — | — |
| recovery-inverted | FAIL | 0.007 | 0.183 | 0.775 | — | transient_height |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/weak-one-rotor-fpv.pdf` et `traces/weak-one-rotor/fpv/`.
