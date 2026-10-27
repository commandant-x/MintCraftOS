# Régression native 0.4.0 — enveloppe de stabilité

96 scénarios : 4 montages × 8 mouvements × 3 variantes. 60 s par scénario, contrôle 20 Hz, physique 200 Hz. Modèle synthétique 6DOF indépendant ; aucune qualification Minecraft.

`baseline` = 0.3.5 ; `fixed` = 0.4.0 avec facteur 1 ; `limited` = 0.4.0 avec facteur imposé 0,5. Ce banc compare les effets de la réduction d’inclinaison ; il ne simule pas la politique adaptative complète. Celle-ci est vérifiée séparément dans les tests LuaJ.

Les 32 traces complètes à facteur 1 sont identiques octet par octet à celles de la 0.3.5. La réduction ne garantit pas la stabilité : les échecs restent visibles ci-dessous.

| Montage | Variante | PASS | FAIL | REFUSED |
| --- | --- | ---: | ---: | ---: |
| mixed-propellers | baseline | 6 | 2 | 0 |
| mixed-propellers | fixed | 6 | 2 | 0 |
| mixed-propellers | limited | 7 | 1 | 0 |
| reference | baseline | 8 | 0 | 0 |
| reference | fixed | 8 | 0 | 0 |
| reference | limited | 8 | 0 | 0 |
| slow-radio | baseline | 2 | 6 | 0 |
| slow-radio | fixed | 2 | 6 | 0 |
| slow-radio | limited | 2 | 6 | 0 |
| small-propellers | baseline | 7 | 1 | 0 |
| small-propellers | fixed | 7 | 1 | 0 |
| small-propellers | limited | 7 | 1 | 0 |

## Chaque mouvement

| Montage | Variante | Mouvement | État | Critères échoués |
| --- | --- | --- | --- | --- |
| reference | baseline | hover | PASS | — |
| reference | baseline | load-swing | PASS | — |
| reference | baseline | forward-left | PASS | — |
| reference | baseline | brake | PASS | — |
| reference | baseline | climb | PASS | — |
| reference | baseline | descend | PASS | — |
| reference | baseline | vertical-cycle | PASS | — |
| reference | baseline | recovery-inverted | PASS | — |
| reference | fixed | hover | PASS | — |
| reference | fixed | load-swing | PASS | — |
| reference | fixed | forward-left | PASS | — |
| reference | fixed | brake | PASS | — |
| reference | fixed | climb | PASS | — |
| reference | fixed | descend | PASS | — |
| reference | fixed | vertical-cycle | PASS | — |
| reference | fixed | recovery-inverted | PASS | — |
| reference | limited | hover | PASS | — |
| reference | limited | load-swing | PASS | — |
| reference | limited | forward-left | PASS | — |
| reference | limited | brake | PASS | — |
| reference | limited | climb | PASS | — |
| reference | limited | descend | PASS | — |
| reference | limited | vertical-cycle | PASS | — |
| reference | limited | recovery-inverted | PASS | — |
| small-propellers | baseline | hover | PASS | — |
| small-propellers | baseline | load-swing | PASS | — |
| small-propellers | baseline | forward-left | PASS | — |
| small-propellers | baseline | brake | PASS | — |
| small-propellers | baseline | climb | PASS | — |
| small-propellers | baseline | descend | PASS | — |
| small-propellers | baseline | vertical-cycle | PASS | — |
| small-propellers | baseline | recovery-inverted | FAIL | transient_height, recovery |
| small-propellers | fixed | hover | PASS | — |
| small-propellers | fixed | load-swing | PASS | — |
| small-propellers | fixed | forward-left | PASS | — |
| small-propellers | fixed | brake | PASS | — |
| small-propellers | fixed | climb | PASS | — |
| small-propellers | fixed | descend | PASS | — |
| small-propellers | fixed | vertical-cycle | PASS | — |
| small-propellers | fixed | recovery-inverted | FAIL | transient_height, recovery |
| small-propellers | limited | hover | PASS | — |
| small-propellers | limited | load-swing | PASS | — |
| small-propellers | limited | forward-left | PASS | — |
| small-propellers | limited | brake | PASS | — |
| small-propellers | limited | climb | PASS | — |
| small-propellers | limited | descend | PASS | — |
| small-propellers | limited | vertical-cycle | PASS | — |
| small-propellers | limited | recovery-inverted | FAIL | transient_height, recovery |
| mixed-propellers | baseline | hover | PASS | — |
| mixed-propellers | baseline | load-swing | PASS | — |
| mixed-propellers | baseline | forward-left | PASS | — |
| mixed-propellers | baseline | brake | PASS | — |
| mixed-propellers | baseline | climb | PASS | — |
| mixed-propellers | baseline | descend | PASS | — |
| mixed-propellers | baseline | vertical-cycle | FAIL | transient_height |
| mixed-propellers | baseline | recovery-inverted | FAIL | transient_height |
| mixed-propellers | fixed | hover | PASS | — |
| mixed-propellers | fixed | load-swing | PASS | — |
| mixed-propellers | fixed | forward-left | PASS | — |
| mixed-propellers | fixed | brake | PASS | — |
| mixed-propellers | fixed | climb | PASS | — |
| mixed-propellers | fixed | descend | PASS | — |
| mixed-propellers | fixed | vertical-cycle | FAIL | transient_height |
| mixed-propellers | fixed | recovery-inverted | FAIL | transient_height |
| mixed-propellers | limited | hover | PASS | — |
| mixed-propellers | limited | load-swing | PASS | — |
| mixed-propellers | limited | forward-left | PASS | — |
| mixed-propellers | limited | brake | PASS | — |
| mixed-propellers | limited | climb | PASS | — |
| mixed-propellers | limited | descend | PASS | — |
| mixed-propellers | limited | vertical-cycle | PASS | — |
| mixed-propellers | limited | recovery-inverted | FAIL | transient_height |
| slow-radio | baseline | hover | PASS | — |
| slow-radio | baseline | load-swing | PASS | — |
| slow-radio | baseline | forward-left | FAIL | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| slow-radio | baseline | brake | FAIL | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| slow-radio | baseline | climb | FAIL | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height |
| slow-radio | baseline | descend | FAIL | transient_height |
| slow-radio | baseline | vertical-cycle | FAIL | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_vertical_rate |
| slow-radio | baseline | recovery-inverted | FAIL | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, recovery |
| slow-radio | fixed | hover | PASS | — |
| slow-radio | fixed | load-swing | PASS | — |
| slow-radio | fixed | forward-left | FAIL | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| slow-radio | fixed | brake | FAIL | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, active_height, braking |
| slow-radio | fixed | climb | FAIL | tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height |
| slow-radio | fixed | descend | FAIL | transient_height |
| slow-radio | fixed | vertical-cycle | FAIL | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_vertical_rate |
| slow-radio | fixed | recovery-inverted | FAIL | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, recovery |
| slow-radio | limited | hover | PASS | — |
| slow-radio | limited | load-swing | PASS | — |
| slow-radio | limited | forward-left | FAIL | tail_tilt, tail_speed_rms, final_speed, braking |
| slow-radio | limited | brake | FAIL | tail_height_span, tail_tilt, tail_speed_rms, braking |
| slow-radio | limited | climb | FAIL | tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height |
| slow-radio | limited | descend | FAIL | transient_height |
| slow-radio | limited | vertical-cycle | FAIL | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, transient_tilt, active_attitude, active_vertical_rate |
| slow-radio | limited | recovery-inverted | FAIL | complete, tail_height_peak, tail_height_rms, tail_height_span, tail_tilt, tail_speed_rms, final_speed, transient_height, recovery |

Les PDF dans `plots/` montrent chaque trajectoire, altitude, assiette, vitesse et sortie Link. Les excursions et mesures détaillées restent dans `results.json`. L’archive contient les traces intégrales, les sources figées, la plante et les paramètres. La politique peut réduire la demande horizontale et demander une pause ; elle ne remplace pas un modèle physique correct et ne coupe pas mécaniquement les moteurs.
