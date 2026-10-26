# paired-rotors / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.004 | 0.023 | 0.000 | — | — |
| cold-hover | PASS | 0.007 | 0.023 | 0.000 | — | — |
| climb | FAIL | 0.007 | 0.015 | 0.000 | — | transient_height |
| descend | PASS | 0.019 | 0.044 | 0.000 | — | — |
| forward | FAIL | 0.039 | 0.118 | 0.266 | 4.600 | active_height |
| reverse | FAIL | 0.039 | 0.118 | 0.266 | 4.600 | active_height |
| left | FAIL | 0.025 | 0.095 | 0.343 | 4.850 | active_height |
| right | FAIL | 0.025 | 0.095 | 0.343 | 4.850 | active_height |
| forward-left | FAIL | 0.036 | 0.087 | 0.323 | 4.700 | active_height |
| forward-right | FAIL | 0.045 | 0.182 | 0.249 | 4.650 | active_height |
| reverse-left | FAIL | 0.045 | 0.182 | 0.249 | 4.650 | active_height |
| reverse-right | FAIL | 0.036 | 0.087 | 0.323 | 4.700 | active_height |
| turn-left | FAIL | 0.052 | 0.078 | 0.279 | 4.250 | active_height |
| turn-right | FAIL | 0.014 | 0.186 | 0.283 | 4.300 | active_height |
| climb-forward | PASS | 0.074 | 0.145 | 0.237 | 5.100 | — |
| descend-left | FAIL | 0.018 | 0.152 | 0.321 | 3.850 | transient_height |
| vertical-cycle | FAIL | 0.003 | 0.018 | 0.000 | — | transient_height |
| reverse-command | FAIL | 0.005 | 0.136 | 0.424 | 3.950 | active_height |
| brake | FAIL | 0.039 | 0.118 | 0.266 | 4.600 | active_height |
| slalom | FAIL | 0.054 | 0.106 | 0.276 | 4.350 | active_height, motion |
| gust | PASS | 0.010 | 0.031 | 0.366 | — | — |
| load-swing | PASS | 0.056 | 0.126 | 0.216 | — | — |
| recovery-diagonal | PASS | 0.067 | 0.153 | 0.247 | — | — |
| recovery-inverted | PASS | 0.025 | 0.103 | 0.312 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/paired-rotors-fpv.pdf` et `traces/paired-rotors/fpv/`.
