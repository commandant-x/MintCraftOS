# Sputnik 0.2.0 — banc universel

**10/10 scénarios réussis. Plante synthétique indépendante, LuaJ réel ; aucun essai dans le monde Minecraft.**

Les échecs sont conservés. Un succès du maintien ne qualifie pas une mission ou un axe absent. Les excursions transitoires sont affichées séparément. Les hypothèses complètes et empreintes sont dans `summary.json`.

| Architecture | Scénario | Résultat | Erreur finale hauteur m | Excursion hauteur max m | Inclinaison max ° | Vitesse finale m/s | RMS vitesse 10 s |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| Venator | hover | PASS | 0.0002 | 0.0014 | 0.0000 | 0.0017 | 0.0021 |
| Venator | altitude | PASS | 0.0000 | 1.0002 | 0.0000 | 0.0014 | 0.0022 |
| Venator | forward | PASS | 0.0002 | 0.0014 | 0.0000 | 0.0375 | 0.0299 |
| Venator | reverse | PASS | 0.0002 | 0.0014 | 0.0000 | 0.0326 | 0.0301 |
| Venator | turn | PASS | 0.0002 | 0.0014 | 0.0000 | 0.0294 | 0.0296 |
| Venator | mass | PASS | 0.0006 | 0.1676 | 0.0000 | 0.0033 | 0.0024 |
| Venator | calibration | PASS | 0.0001 | 0.6156 | 0.1472 | 0.0091 | 0.0299 |
| Venator | mission | PASS | 0.0002 | 1.2321 | 0.1472 | 0.0386 | 0.0301 |
| Venator | mission_straight | PASS | 0.0003 | 1.2321 | 0.1472 | 0.0344 | 0.0296 |
| Venator | cruise | PASS | 0.0002 | 0.0014 | 0.0000 | 0.0374 | 0.0298 |
