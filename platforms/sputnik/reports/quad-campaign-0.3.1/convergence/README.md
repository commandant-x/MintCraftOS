# Sensibilité au pas de mécanique : 200 / 400 Hz

Le contrôleur reste à 20 Hz ; seuls le nombre de sous-pas et leur durée changent. Les échecs du contrôleur ne deviennent pas des succès par définition. Les variations sont publiées même si elles changent une classification.

| Contrôleur | Mouvement | 200 Hz | 400 Hz | Même classification | Écart pic hauteur m |
| --- | --- | --- | --- | --- | ---: |
| standard | hover | PASS | PASS | True | 0.00121 |
| standard | forward-left | FAIL | FAIL | True | 0.15481 |
| standard | turn-left | FAIL | FAIL | True | 0.02355 |
| standard | load-swing | FAIL | FAIL | True | -0.00358 |
| fpv | hover | PASS | PASS | True | 0.0 |
| fpv | forward-left | FAIL | FAIL | True | 0.02481 |
| fpv | turn-left | FAIL | FAIL | True | -1.15596 |
| fpv | load-swing | PASS | PASS | True | -0.34702 |

Les conclusions sensibles au pas doivent être considérées comme non robustes. Cette vérification ne couvre pas tous les montages ni le solveur Minecraft. Les traces et la variante exacte du banc sont dans `convergence-traces.zip`.
