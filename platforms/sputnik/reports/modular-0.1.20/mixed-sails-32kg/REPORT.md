# Sputnik 0.1.20 — banc numérique 3D

**Simulation indépendante paramétrée ; pas un jumeau mesuré du véhicule du joueur.**

Cas de référence réussis : **5/6**. Les cas « stress » modifient volontairement les hypothèses du contrôleur ; ils ne sont pas exclus des résultats.

Les véritables scripts Lua livrés sont exécutés dans le LuaJ de Cosmonautics. La plante utilise quaternion, forces aux quatre points, couples et inerties, dynamique rigide à 200 Hz, régime retardé à 20 Hz et propagation du graphe à un tick. La plante continue après un défaut : le repli ne fige pas le véhicule.

Critères : actif tout le long, erreur finale altitude < 0,3 m, vitesse finale < 0,2 m/s, erreur horizontale finale < 0,3 m et inclinaison maximale < 25°. Sur les dix dernières secondes : inclinaison RMS < 2° et vitesse RMS < 0,2 m/s. Une réussite ne borne pas les excursions transitoires : elles sont indiquées séparément.

| Scénario | Stress | Résultat | Erreur finale (m) | Inclinaison max (°) | RMS angle (°) | RMS vitesse (m/s) | T1 (s) | Défaut |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| level_hover | false | PASS | 0.069 | 0.39 | 0.163 | 0.042 | -1.00 | — |
| tilt_pitch_5deg | false | PASS | 0.013 | 4.97 | 0.203 | 0.046 | -1.00 | — |
| space_then_hold | false | PASS | 0.008 | 2.30 | 0.263 | 0.045 | -1.00 | — |
| forward_then_brake | false | PASS | 0.021 | 11.85 | 0.172 | 0.051 | 1.10 | — |
| mass_loss_15percent | false | FAIL | 0.103 | 0.77 | 0.200 | 0.056 | -1.00 | — |
| course_left_arc | false | PASS | 0.046 | 15.97 | 0.134 | 0.034 | 1.10 | — |

Paramètres de base : 32 kg, inerties diagonales supposées 250/400/230 kg·m², demi-largeur 3 m, demi-longueur 5 m, rotors à +1 m de Sputnik, altitude initiale Y=80, centre de masse centré, petits rotors identiques vers le haut, 256 RPM, gravité 11, retard radio 1 tick. Les amortissements 0,05 s⁻¹ sont hypothétiques ; un cas les supprime complètement.

Les signaux 0..15 sont des réductions : 0 = 256 RPM, 1 = 224 RPM et 15 = arrêt. Les traces CSV contiennent les signaux réellement appliqués par la plante et les quatre régimes.

RMS : moyenne quadratique sur les dix dernières secondes. T1 : délai depuis l’appui W pour atteindre 1 m/s vers l’avant ; −1 signifie non atteint pendant l’appui ou non applicable. L’erreur maximale transitoire reste disponible dans le CSV.

La masse et les dimensions sont des paramètres déclarés ; les inerties, le centre de masse et la mécanique ne sont pas mesurés. Le moteur physique Sable et le réseau cinétique Create ne sont pas lancés. Aucune certitude de vol en jeu ni qualification autopilote ne résulte de ce rapport.

Contrôleur SHA256 : `39ae1aee4b68ca2aa7ecbf2aa33a7ea73a7172c9dd87b25a575718ee5a76de7c`.
Plante SHA256 : `54e5e5dfa4877a870c9827c15e86e87a1ed6da7d37d2e8427ab102112b3ef493`.
