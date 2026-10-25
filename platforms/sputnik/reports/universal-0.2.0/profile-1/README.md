# Sputnik 0.2.0 — banc universel

**10/10 scénarios réussis. Plante synthétique indépendante, LuaJ réel ; aucun essai dans le monde Minecraft.**

Les échecs sont conservés. Un succès du maintien ne qualifie pas une mission ou un axe absent. Les excursions transitoires sont affichées séparément. Les hypothèses complètes et empreintes sont dans `summary.json`.

| Architecture | Scénario | Résultat | Erreur finale hauteur m | Excursion hauteur max m | Inclinaison max ° | Vitesse finale m/s | RMS vitesse 10 s |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| Quad petites | hover | PASS | 0.0002 | 0.0014 | 0.0000 | 0.0017 | 0.0021 |
| Quad petites | altitude | PASS | 0.0000 | 1.0002 | 0.0000 | 0.0014 | 0.0022 |
| Quad petites | forward | PASS | 0.0001 | 0.2141 | 8.3668 | 0.0094 | 0.0098 |
| Quad petites | reverse | PASS | 0.0004 | 0.2141 | 8.3668 | 0.0104 | 0.0150 |
| Quad petites | turn | PASS | 0.0014 | 0.1906 | 7.9447 | 0.0125 | 0.0109 |
| Quad petites | mass | PASS | 0.0006 | 0.1676 | 0.0000 | 0.0033 | 0.0024 |
| Quad petites | calibration | PASS | 0.0003 | 0.6146 | 4.2307 | 0.0214 | 0.0138 |
| Quad petites | mission | PASS | 0.0012 | 1.2283 | 5.3541 | 0.0137 | 0.0079 |
| Quad petites | mission_straight | PASS | 0.0002 | 1.2429 | 6.7312 | 0.0047 | 0.0137 |
| Quad petites | cruise | PASS | 0.0011 | 0.1637 | 9.1828 | 0.0157 | 0.0080 |
