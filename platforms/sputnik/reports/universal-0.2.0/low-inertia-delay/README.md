# Sputnik 0.2.0 — banc universel

**3/6 scénarios réussis. Plante synthétique indépendante, LuaJ réel ; aucun essai dans le monde Minecraft.**

Les échecs sont conservés. Un succès du maintien ne qualifie pas une mission ou un axe absent. Les excursions transitoires sont affichées séparément. Les hypothèses complètes et empreintes sont dans `summary.json`.

| Architecture | Scénario | Résultat | Erreur finale hauteur m | Excursion hauteur max m | Inclinaison max ° | Vitesse finale m/s | RMS vitesse 10 s |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| Quad petites | hover | PASS | 0.0092 | 0.0172 | 0.3818 | 0.0071 | 0.0129 |
| Quad petites | forward | PASS | 0.0059 | 0.3267 | 13.5116 | 0.0153 | 0.0131 |
| Quad petites | mass | PASS | 0.0040 | 0.1972 | 0.3432 | 0.0151 | 0.0112 |
| Quad modulaire hétérogène | hover | FAIL | 2.2667 | 11.4992 | 25.9789 | 1.8322 | 2.3557 |
| Quad modulaire hétérogène | forward | FAIL | 11.2880 | 11.2880 | 23.4965 | 1.8459 | 1.8206 |
| Quad modulaire hétérogène | mass | FAIL | 12.2791 | 12.6267 | 25.7644 | 1.8018 | 1.9776 |
