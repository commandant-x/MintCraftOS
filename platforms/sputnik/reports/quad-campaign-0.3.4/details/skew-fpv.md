# skew / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.004 | 0.046 | 0.102 | — | — |
| cold-hover | PASS | 0.004 | 0.051 | 0.146 | — | — |
| climb | PASS | 0.017 | 0.057 | 0.143 | — | — |
| descend | PASS | 0.004 | 0.038 | 0.118 | — | — |
| forward | PASS | 0.004 | 0.033 | 0.189 | 4.550 | — |
| reverse | PASS | 0.010 | 0.044 | 0.157 | 4.600 | — |
| left | PASS | 0.020 | 0.051 | 0.137 | 4.500 | — |
| right | PASS | 0.002 | 0.051 | 0.141 | 4.700 | — |
| forward-left | PASS | 0.009 | 0.053 | 0.159 | 4.650 | — |
| forward-right | PASS | 0.007 | 0.073 | 0.125 | 4.600 | — |
| reverse-left | PASS | 0.005 | 0.048 | 0.147 | 4.450 | — |
| reverse-right | PASS | 0.010 | 0.034 | 0.122 | 4.650 | — |
| turn-left | PASS | 0.008 | 0.053 | 0.146 | 4.350 | — |
| turn-right | PASS | 0.006 | 0.051 | 0.130 | 4.500 | — |
| climb-forward | PASS | 0.000 | 0.047 | 0.171 | 5.250 | — |
| descend-left | FAIL | 0.007 | 0.050 | 0.193 | 3.900 | transient_height |
| vertical-cycle | PASS | 0.001 | 0.041 | 0.131 | — | — |
| reverse-command | PASS | 0.015 | 0.060 | 0.125 | 4.100 | — |
| brake | PASS | 0.004 | 0.033 | 0.189 | 4.550 | — |
| slalom | PASS | 0.001 | 0.041 | 0.135 | 4.400 | — |
| gust | PASS | 0.012 | 0.070 | 0.172 | — | — |
| load-swing | PASS | 0.013 | 0.097 | 0.271 | — | — |
| recovery-diagonal | PASS | 0.016 | 0.036 | 0.122 | — | — |
| recovery-inverted | PASS | 0.005 | 0.050 | 0.132 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/skew-fpv.pdf` et `traces/skew/fpv/`.
