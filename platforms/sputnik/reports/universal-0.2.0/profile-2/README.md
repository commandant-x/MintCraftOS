# Sputnik 0.2.0 — banc universel

**9/10 scénarios réussis. Plante synthétique indépendante, LuaJ réel ; aucun essai dans le monde Minecraft.**

Les échecs sont conservés. Un succès du maintien ne qualifie pas une mission ou un axe absent. Les excursions transitoires sont affichées séparément. Les hypothèses complètes et empreintes sont dans `summary.json`.

| Architecture | Scénario | Résultat | Erreur finale hauteur m | Excursion hauteur max m | Inclinaison max ° | Vitesse finale m/s | RMS vitesse 10 s |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| Ballon/gouverne | hover | PASS | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 |
| Ballon/gouverne | altitude | PASS | 0.0006 | 1.0000 | 0.0000 | 0.0129 | 0.0093 |
| Ballon/gouverne | forward | PASS | 0.0000 | 0.0000 | 0.0000 | 0.0091 | 0.0082 |
| Ballon/gouverne | reverse | PASS | 0.0000 | 0.0000 | 0.0000 | 0.0089 | 0.0082 |
| Ballon/gouverne | turn | PASS | 0.0000 | 0.0000 | 0.0000 | 0.0041 | 0.0082 |
| Ballon/gouverne | mass | PASS | 0.0005 | 0.2302 | 0.0000 | 0.0010 | 0.0025 |
| Ballon/gouverne | calibration | PASS | 0.0033 | 0.5621 | 0.0000 | 0.0120 | 0.0100 |
| Ballon/gouverne | mission | FAIL | 1.0019 | 1.1243 | 0.0000 | 0.0143 | 0.0123 |
| Ballon/gouverne | mission_straight | PASS | 0.0045 | 1.1243 | 0.0000 | 0.0103 | 0.0105 |
| Ballon/gouverne | cruise | PASS | 0.0000 | 0.0000 | 0.0000 | 0.0105 | 0.0082 |
