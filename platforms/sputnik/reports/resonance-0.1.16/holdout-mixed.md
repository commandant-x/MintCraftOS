# Sputnik 0.1.16 — banc numérique 3D

**Simulation indépendante paramétrée ; pas un jumeau mesuré du véhicule du joueur.**

Cas de référence réussis : **10/10**. Les cas « stress » modifient volontairement les hypothèses du contrôleur ; ils ne sont pas exclus des résultats.

Les véritables scripts Lua livrés sont exécutés dans le LuaJ de Cosmonautics. La plante utilise quaternion, forces aux quatre points, couples et inerties, dynamique rigide à 200 Hz, régime retardé à 20 Hz et propagation du graphe à un tick. La plante continue après un défaut : le repli ne fige pas le véhicule.

Critères : actif tout le long, erreur finale altitude < 0,3 m, vitesse finale < 0,2 m/s, erreur horizontale finale < 0,3 m et inclinaison maximale < 25°. Sur les dix dernières secondes : inclinaison RMS < 2° et vitesse RMS < 0,2 m/s. Une réussite ne borne pas les excursions transitoires : elles sont indiquées séparément.

| Scénario | Stress | Résultat | Erreur finale (m) | Inclinaison max (°) | RMS angle (°) | RMS vitesse (m/s) | T50 (s) | Défaut |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| level_hover | false | PASS | 0.003 | 0.00 | 0.000 | 0.007 | -1.00 | — |
| level_drop_5ms | false | PASS | 0.024 | 0.00 | 0.000 | 0.009 | -1.00 | — |
| tilt_yaw_90deg | false | PASS | 0.001 | 4.98 | 0.087 | 0.015 | -1.00 | — |
| forward_then_brake | false | PASS | 0.004 | 7.44 | 0.075 | 0.020 | 1.60 | — |
| diagonal_then_brake | false | PASS | 0.003 | 10.32 | 0.104 | 0.021 | -1.00 | — |
| radio_delay_4ticks | false | PASS | 0.004 | 5.00 | 0.077 | 0.011 | -1.00 | — |
| inertia_quarter | false | PASS | 0.000 | 4.97 | 0.221 | 0.007 | -1.00 | — |
| inertia_eighth | false | PASS | 0.001 | 4.96 | 0.098 | 0.009 | -1.00 | — |
| reverse_every_half_second | false | PASS | 0.005 | 2.95 | 0.052 | 0.013 | -1.00 | — |
| periodic_pitch_05hz | false | PASS | 0.008 | 3.69 | 0.061 | 0.015 | -1.00 | — |

Paramètres de base : 32 kg, inerties diagonales supposées 800/600/60 kg·m², demi-largeur 3 m, demi-longueur 5 m, rotors à +1 m de Sputnik, altitude initiale Y=80, centre de masse centré, petits rotors identiques vers le haut, 256 RPM, gravité 11, retard radio 1 tick. Les amortissements 0,05 s⁻¹ sont hypothétiques ; un cas les supprime complètement.

Les signaux 0..15 sont des réductions : 0 = 256 RPM, 1 = 224 RPM et 15 = arrêt. Les traces CSV contiennent les signaux réellement appliqués par la plante et les quatre régimes.

RMS : moyenne quadratique sur les dix dernières secondes. T50 : délai depuis l’appui W pour atteindre 1 m/s vers l’avant (50 % de la consigne de 2 m/s) ; −1 signifie non atteint pendant l’appui ou non applicable. L’erreur maximale transitoire reste disponible dans le CSV.

La masse et les dimensions sont des paramètres déclarés ; les inerties, le centre de masse et la mécanique ne sont pas mesurés. Le moteur physique Sable et le réseau cinétique Create ne sont pas lancés. Aucune certitude de vol en jeu ni qualification autopilote ne résulte de ce rapport.

Contrôleur SHA256 : `d9b4c31aec0be26c85e624d0001591fb139f4eb86558addd5b071d2e8957c3d6`.
Plante SHA256 : `2b0bc26de6b7c0692de1f716074875a963d78e30f558e0706f9aaca37ca1d522`.
