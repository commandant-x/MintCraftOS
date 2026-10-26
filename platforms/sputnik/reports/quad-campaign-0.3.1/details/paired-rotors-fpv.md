# paired-rotors / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.008 | 0.026 | 0.000 | — | — |
| cold-hover | PASS | 0.001 | 0.026 | 0.000 | — | — |
| climb | FAIL | 0.002 | 0.036 | 0.000 | — | transient_height |
| descend | PASS | 0.024 | 0.073 | 0.000 | — | — |
| forward | FAIL | 0.035 | 0.143 | 0.762 | 4.600 | transient_height, active_height |
| reverse | FAIL | 0.153 | 0.168 | 0.878 | 4.750 | transient_height, active_height |
| left | FAIL | 0.225 | 0.320 | 1.303 | 5.050 | transient_height, active_height |
| right | FAIL | 0.033 | 0.217 | 0.869 | 4.950 | transient_height, active_height |
| forward-left | FAIL | 0.029 | 0.354 | 1.190 | 5.150 | transient_height, active_height |
| forward-right | FAIL | 0.000 | 0.259 | 0.409 | 5.100 | transient_height, active_height |
| reverse-left | FAIL | 0.086 | 0.116 | 0.025 | 5.200 | transient_height, active_height |
| reverse-right | FAIL | 0.239 | 0.387 | 1.260 | 5.200 | transient_height, active_height |
| turn-left | FAIL | 0.021 | 0.280 | 0.817 | 2.900 | transient_height, active_attitude, active_height, motion |
| turn-right | FAIL | 0.129 | 0.118 | 0.041 | 3.050 | transient_height, active_attitude, active_height, motion |
| climb-forward | FAIL | 0.159 | 0.187 | 1.482 | 5.500 | transient_height |
| descend-left | PASS | 0.039 | 0.342 | 1.225 | 4.400 | — |
| vertical-cycle | FAIL | 0.004 | 0.040 | 0.000 | — | transient_height |
| reverse-command | FAIL | 0.047 | 0.360 | 0.846 | 4.250 | transient_height, active_height |
| brake | FAIL | 0.035 | 0.143 | 0.762 | 4.600 | transient_height, active_height |
| slalom | FAIL | 0.026 | 0.307 | 1.026 | 5.050 | transient_height, active_attitude, active_height, motion |
| gust | PASS | 0.109 | 0.266 | 1.084 | — | — |
| load-swing | PASS | 0.135 | 0.446 | 0.881 | — | — |
| recovery-diagonal | PASS | 0.171 | 0.332 | 0.794 | — | — |
| recovery-inverted | PASS | 0.034 | 0.468 | 0.865 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/paired-rotors-fpv.pdf` et `traces/paired-rotors/fpv/`.
