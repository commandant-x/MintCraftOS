# Sputnik 0.2.0 — banc universel

**10/10 scénarios réussis. Plante synthétique indépendante, LuaJ réel ; aucun essai dans le monde Minecraft.**

Les échecs sont conservés. Un succès du maintien ne qualifie pas une mission ou un axe absent. Les excursions transitoires sont affichées séparément. Les hypothèses complètes et empreintes sont dans `summary.json`.

| Architecture | Scénario | Résultat | Erreur finale hauteur m | Excursion hauteur max m | Inclinaison max ° | Vitesse finale m/s | RMS vitesse 10 s |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| Quad modulaire hétérogène | hover | PASS | 0.0441 | 0.2499 | 1.1559 | 0.0395 | 0.1293 |
| Quad modulaire hétérogène | altitude | PASS | 0.0307 | 1.2367 | 3.3845 | 0.2631 | 0.1634 |
| Quad modulaire hétérogène | forward | PASS | 0.0130 | 1.3197 | 12.5484 | 0.1450 | 0.1782 |
| Quad modulaire hétérogène | reverse | PASS | 0.1062 | 2.1230 | 15.2084 | 0.0498 | 0.1685 |
| Quad modulaire hétérogène | turn | PASS | 0.0598 | 1.0387 | 12.0305 | 0.2434 | 0.1530 |
| Quad modulaire hétérogène | mass | PASS | 0.2291 | 0.4503 | 3.2969 | 0.1799 | 0.2812 |
| Quad modulaire hétérogène | calibration | PASS | 0.1563 | 0.6844 | 4.9768 | 0.0261 | 0.1559 |
| Quad modulaire hétérogène | mission | PASS | 0.0078 | 1.8551 | 10.7815 | 0.0367 | 0.1540 |
| Quad modulaire hétérogène | mission_straight | PASS | 0.0152 | 1.6929 | 10.4866 | 0.1857 | 0.1442 |
| Quad modulaire hétérogène | cruise | PASS | 0.1680 | 0.8229 | 14.5557 | 0.1175 | 0.1627 |
