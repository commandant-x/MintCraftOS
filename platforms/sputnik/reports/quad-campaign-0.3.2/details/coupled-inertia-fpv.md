# coupled-inertia / fpv

Protocole : 60 s ; seuils communs et paramètres complets dans `campaign.json`. Les refus ne sont pas des mouvements validés.

| Mouvement | Résultat | Erreur finale hauteur m | Excursion finale m | Assiette finale max ° | Freinage s | Critères échoués |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| hover | PASS | 0.001 | 0.014 | 0.000 | — | — |
| cold-hover | PASS | 0.005 | 0.022 | 0.000 | — | — |
| climb | PASS | 0.007 | 0.023 | 0.000 | — | — |
| descend | PASS | 0.000 | 0.044 | 0.000 | — | — |
| forward | PASS | 0.023 | 0.087 | 1.032 | 4.500 | — |
| reverse | PASS | 0.022 | 0.147 | 0.826 | 4.550 | — |
| left | PASS | 0.016 | 0.131 | 0.967 | 3.700 | — |
| right | PASS | 0.010 | 0.026 | 0.020 | 3.750 | — |
| forward-left | PASS | 0.077 | 0.114 | 0.713 | 4.850 | — |
| forward-right | PASS | 0.002 | 0.025 | 0.016 | 4.750 | — |
| reverse-left | PASS | 0.005 | 0.087 | 0.589 | 4.650 | — |
| reverse-right | PASS | 0.023 | 0.231 | 0.587 | 4.800 | — |
| turn-left | PASS | 0.060 | 0.176 | 0.773 | 4.600 | — |
| turn-right | PASS | 0.037 | 0.165 | 0.766 | 4.550 | — |
| climb-forward | PASS | 0.016 | 0.073 | 0.735 | 5.050 | — |
| descend-left | PASS | 0.021 | 0.053 | 0.021 | 4.650 | — |
| vertical-cycle | PASS | 0.005 | 0.020 | 0.000 | — | — |
| reverse-command | PASS | 0.021 | 0.102 | 0.453 | 3.850 | — |
| brake | PASS | 0.023 | 0.087 | 1.032 | 4.500 | — |
| slalom | PASS | 0.025 | 0.104 | 0.836 | 4.400 | — |
| gust | PASS | 0.079 | 0.107 | 0.496 | — | — |
| load-swing | PASS | 0.009 | 0.189 | 0.921 | — | — |
| recovery-diagonal | PASS | 0.081 | 0.125 | 0.813 | — | — |
| recovery-inverted | PASS | 0.010 | 0.099 | 0.608 | — | — |

Les courbes et traces complètes sont dans les archives listées dans le rapport principal, sous `plots/coupled-inertia-fpv.pdf` et `traces/coupled-inertia/fpv/`.
