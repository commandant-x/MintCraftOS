# Sensibilité au pas de mécanique : 200 / 400 Hz

Le contrôleur reste à 20 Hz ; seuls le nombre de sous-pas et leur durée changent. Les échecs du contrôleur ne deviennent pas des succès par définition. Les variations sont publiées même si elles changent une classification.

| Contrôleur | Mouvement | 200 Hz | 400 Hz | Même classification | Écart pic hauteur m |
| --- | --- | --- | --- | --- | ---: |
| fpv | hover | PASS | PASS | True | -0.00012 |
| fpv | forward-left | PASS | PASS | True | 0.00015 |
| fpv | turn-left | PASS | PASS | True | 0.00638 |
| fpv | load-swing | PASS | PASS | True | -0.00348 |

Les conclusions sensibles au pas doivent être considérées comme non robustes. Cette vérification ne couvre pas tous les montages ni le solveur Minecraft. Les traces et la variante exacte du banc sont dans `convergence-traces.zip`.
