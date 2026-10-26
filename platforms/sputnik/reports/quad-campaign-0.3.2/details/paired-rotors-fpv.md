# paired-rotors / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.008 | 0.026 | 0.000 | — | — |
| cold-hover | PASS | 0.002 | 0.024 | 0.000 | — | — |
| climb | FAIL | 0.010 | 0.033 | 0.000 | — | transient_height |
| descend | PASS | 0.001 | 0.003 | 0.000 | — | — |
| forward | FAIL | 0.007 | 0.023 | 0.017 | 4.700 | active_height |
| reverse | FAIL | 0.007 | 0.023 | 0.017 | 4.700 | active_height |
| left | FAIL | 0.006 | 0.026 | 0.002 | 4.750 | active_height |
| right | FAIL | 0.006 | 0.026 | 0.002 | 4.750 | active_height |
| forward-left | FAIL | 0.025 | 0.232 | 1.136 | 4.650 | active_height |
| forward-right | FAIL | 0.025 | 0.232 | 1.136 | 4.650 | active_height |
| reverse-left | FAIL | 0.025 | 0.232 | 1.136 | 4.650 | active_height |
| reverse-right | FAIL | 0.025 | 0.232 | 1.136 | 4.650 | active_height |
| turn-left | PASS | 0.045 | 0.093 | 1.025 | 4.300 | — |
| turn-right | PASS | 0.045 | 0.093 | 1.025 | 4.300 | — |
| climb-forward | PASS | 0.051 | 0.305 | 2.403 | 4.950 | — |
| descend-left | FAIL | 0.031 | 0.386 | 0.047 | 4.700 | transient_height |
| vertical-cycle | FAIL | 0.003 | 0.028 | 0.000 | — | transient_height |
| reverse-command | FAIL | 0.007 | 0.050 | 0.126 | 3.950 | active_height |
| brake | FAIL | 0.007 | 0.023 | 0.017 | 4.700 | active_height |
| slalom | FAIL | 0.037 | 0.241 | 0.724 | 4.450 | motion |
| gust | PASS | 0.267 | 0.329 | 2.141 | — | — |
| load-swing | PASS | 0.009 | 0.428 | 1.355 | — | — |
| recovery-diagonal | FAIL | 0.052 | 0.348 | 1.126 | — | final_speed |
| recovery-inverted | PASS | 0.095 | 0.396 | 0.915 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/paired-rotors-fpv.pdf` et `traces/paired-rotors/fpv/`.
