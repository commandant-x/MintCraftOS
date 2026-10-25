# Sputnik 0.2.0 — banc universel

**10/10 scénarios réussis. Plante synthétique indépendante, LuaJ réel ; aucun essai dans le monde Minecraft.**

Les échecs sont conservés. Un succès du maintien ne qualifie pas une mission ou un axe absent. Les excursions transitoires sont affichées séparément. Les hypothèses complètes et empreintes sont dans `summary.json`.

| Architecture | Scénario | Résultat | Erreur finale hauteur m | Excursion hauteur max m | Inclinaison max ° | Vitesse finale m/s | RMS vitesse 10 s |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| Hélicoptère | hover | PASS | 0.0063 | 0.0063 | 0.0000 | 0.0112 | 0.0074 |
| Hélicoptère | altitude | PASS | 0.0012 | 0.9954 | 0.0000 | 0.0037 | 0.0077 |
| Hélicoptère | forward | PASS | 0.0063 | 0.0063 | 0.0000 | 0.0144 | 0.0111 |
| Hélicoptère | reverse | PASS | 0.0063 | 0.0063 | 0.0000 | 0.0143 | 0.0111 |
| Hélicoptère | turn | PASS | 0.0063 | 0.0063 | 0.0000 | 0.0119 | 0.0110 |
| Hélicoptère | mass | PASS | 0.0003 | 0.2031 | 0.0000 | 0.0226 | 0.0127 |
| Hélicoptère | calibration | PASS | 0.0090 | 0.6562 | 0.0000 | 0.0111 | 0.0122 |
| Hélicoptère | mission | PASS | 0.0029 | 1.2947 | 0.0000 | 0.0131 | 0.0129 |
| Hélicoptère | mission_straight | PASS | 0.0012 | 1.2947 | 0.0000 | 0.0063 | 0.0107 |
| Hélicoptère | cruise | PASS | 0.0063 | 0.0063 | 0.0000 | 0.0144 | 0.0111 |
