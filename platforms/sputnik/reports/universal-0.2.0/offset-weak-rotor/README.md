# Sputnik 0.2.0 — banc universel

**2/6 scénarios réussis. Plante synthétique indépendante, LuaJ réel ; aucun essai dans le monde Minecraft.**

Les échecs sont conservés. Un succès du maintien ne qualifie pas une mission ou un axe absent. Les excursions transitoires sont affichées séparément. Les hypothèses complètes et empreintes sont dans `summary.json`.

| Architecture | Scénario | Résultat | Erreur finale hauteur m | Excursion hauteur max m | Inclinaison max ° | Vitesse finale m/s | RMS vitesse 10 s |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| Quad petites | hover | FAIL | 0.0005 | 0.5302 | 5.7542 | 0.7888 | 0.7929 |
| Quad petites | forward | FAIL | 0.0147 | 0.6403 | 12.3662 | 0.7964 | 0.7936 |
| Quad petites | mass | PASS | 0.0207 | 0.5302 | 5.7542 | 0.0239 | 0.0333 |
| Quad modulaire hétérogène | hover | FAIL | 0.1870 | 0.8144 | 3.9972 | 0.3053 | 0.3697 |
| Quad modulaire hétérogène | forward | FAIL | 0.0641 | 2.5201 | 12.3832 | 0.3462 | 0.3890 |
| Quad modulaire hétérogène | mass | PASS | 0.1947 | 0.8516 | 4.2724 | 0.2201 | 0.3472 |
