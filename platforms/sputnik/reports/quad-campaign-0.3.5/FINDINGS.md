# Quad 0.3.5 : charge suspendue et régressions

Le correctif adapte le maintien horizontal à l’effort vertical estimé, permet d’apprendre cet effort pendant les oscillations modérées et renforce conditionnellement le freinage vertical. Aucun nouveau paramètre de charge, changement de fréquence ou régime mécanique. Le contrôleur standard reste inchangé.

## Charge suspendue

Les [96 essais natifs avec câble](../quad-load-0.3.5/README.md) passent de 9/48 à 29/48 succès, avec les huit maintiens réussis et aucun ancien succès perdu sur ce banc. Les mouvements encore en échec restent détaillés. Corde courte : inclinaison terminale maximale du quad 11,08° → 0,19°, câble 20,68° → 0,50°, pic d’erreur verticale sur tout l’essai 2,40 m → 0,85 m. La masse de charge n’est jamais fournie au contrôleur. Ce n’est pas un vrai joint Minecraft.

## Campagne générale

**406 PASS / 146 FAIL / 24 REFUSED**, contre 386/166/24 en 0.3.4. 24 anciens échecs deviennent des réussites ; 4 anciennes réussites régressent. La référence conserve 24/24. Les mêmes critères historiques, protocoles, modèles physiques et sources 256 RPM sont conservés.

| Avant | Après | Nombre |
| --- | --- | ---: |
| FAIL | FAIL | 142 |
| FAIL | PASS | 24 |
| PASS | FAIL | 4 |
| PASS | PASS | 382 |
| REFUSED | REFUSED | 24 |

## Régressions

| Montage | Mouvement | Critères échoués après correction |
| --- | --- | --- |
| high-altitude | vertical-cycle | active_attitude |
| mixed-propellers | vertical-cycle | transient_height |
| telemetry-delay | reverse-left | braking |
| telemetry-delay | reverse-command | tail_tilt, tail_speed_rms, final_speed |

## Améliorations

| Montage | Mouvement | Critères échoués après correction |
| --- | --- | --- |
| light-16kg | load-swing | — |
| mixed-propellers | right | — |
| narrow | left | — |
| narrow | right | — |
| pressure-mismatch | climb | — |
| pressure-mismatch | climb-forward | — |
| pressure-mismatch | descend-left | — |
| pressure-mismatch | vertical-cycle | — |
| shifted-com | recovery-inverted | — |
| skew | descend-left | — |
| slow-radio | cold-hover | — |
| slow-radio | load-swing | — |
| small-propellers | load-swing | — |
| telemetry-delay | forward | — |
| telemetry-delay | brake | — |
| telemetry-delay | load-swing | — |
| very-low-inertia | load-swing | — |
| weak-one-rotor | climb | — |
| weak-one-rotor | descend-left | — |
| weak-one-rotor | vertical-cycle | — |
| wide | forward | — |
| wide | reverse | — |
| wide | reverse-command | — |
| wide | brake | — |

## Stabilité transitoire stricte

- 0.3.4 : 329/552 retours durables dans les bandes en huit secondes au plus ; 75 sans seconde terminale entière dans ces bandes.
- 0.3.5 : 353/552 retours durables dans les bandes en huit secondes au plus ; 70 sans seconde terminale entière dans ces bandes.

Bandes inchangées du diagnostic de recherche : hauteur 0,3 m, assiette 2°, |Vy| 0,2 m/s et vitesse horizontale 0,3 m/s après déplacement. Ce ne sont pas des plafonds de vitesse du pilote. Les critères historiques restent séparés.

## Centre de masse et prototype rejeté

Les [72 scénarios COM](../quad-com-0.3.5/README.md) donnent 16/36 succès selon leurs critères par épisode contre 15/36, et 17/36 aux critères historiques contre 14/36. Les cas décentrés, à retard et hors support restent en échec. L’altitude demandée est conservée. Une amélioration moyenne n’efface pas les régressions individuelles.

Le premier prototype renforçait toujours le gain vertical : référence 22/24, translations latérales dépassant 42°. Il a été rejeté avant livraison. Les 24 essais complets et sources sont dans `../quad-load-0.3.5/rejected-prototype.zip`. Le gain précédent est conservé au maintien sans effort extérieur significatif dans la version finale, qui retrouve 24/24 sur la référence.

La sensibilité [200/400 Hz](convergence/README.md) conserve quatre classifications sur quatre. Le profil demeure expérimental : les montages à faibles inerties, latences et fortes poussées conservent des échecs. Aucun vol Minecraft n’est revendiqué.
