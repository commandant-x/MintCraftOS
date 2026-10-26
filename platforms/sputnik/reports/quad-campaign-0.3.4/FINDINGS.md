# Charge décentrée 0.3.4 : gains et régressions

Le nouveau calcul adapte la répartition de poussée à un déséquilibre de couple, sans nouvelle saisie ni changement mécanique. Il conserve l’altitude demandée. Les [72 essais spécifiques](../quad-com-0.3.4/README.md) exécutent réellement des changements de charge ; les succès COM passent de 6/36 à 15/36, et les anciens critères complets de 2/36 à 14/36. Les critères COM sont distincts et les deux scores restent conservés.

## Campagne générale : ne pas confondre amélioration ciblée et qualification universelle

576 cellules : **386 PASS / 166 FAIL / 24 REFUSED**, contre 394/158/24 en 0.3.3. 9 anciens échecs deviennent des réussites, 17 anciennes réussites régressent. La référence conserve 24/24 ; les délais importants, forte poussée relative à la masse et certains montages restent expérimentaux. Les seuils historiques, la mécanique et les protocoles de campagne ne sont pas modifiés.

| Avant | Après | Nombre |
| --- | --- | ---: |
| FAIL | FAIL | 149 |
| FAIL | PASS | 9 |
| PASS | FAIL | 17 |
| PASS | PASS | 377 |
| REFUSED | REFUSED | 24 |

## Régressions conservées

| Montage | Mouvement | Critères échoués |
| --- | --- | --- |
| light-16kg | load-swing | transient_height |
| mixed-propellers | reverse | transient_tilt |
| mixed-propellers | right | transient_tilt |
| mixed-propellers | reverse-right | transient_tilt, braking |
| shifted-com | recovery-inverted | transient_height |
| skew | descend-left | transient_height |
| small-propellers | load-swing | tail_tilt, tail_speed_rms, final_speed |
| telemetry-delay | forward | tail_tilt, tail_speed_rms, final_speed |
| telemetry-delay | reverse | tail_tilt, tail_speed_rms, final_speed |
| telemetry-delay | left | tail_tilt, tail_speed_rms, final_speed, braking |
| telemetry-delay | brake | tail_tilt, tail_speed_rms, final_speed |
| very-low-inertia | load-swing | tail_speed_rms, final_speed |
| weak-one-rotor | recovery-inverted | transient_height |
| wide | forward | transient_tilt |
| wide | reverse | transient_tilt |
| wide | reverse-command | transient_tilt |
| wide | brake | transient_tilt |

## Améliorations aux anciens critères

| Montage | Mouvement |
| --- | --- |
| low-inertia | climb-forward |
| mixed-propellers | descend |
| mixed-propellers | vertical-cycle |
| skew | slalom |
| telemetry-delay | forward-left |
| telemetry-delay | forward-right |
| telemetry-delay | reverse-left |
| telemetry-delay | reverse-right |
| telemetry-delay | turn-left |

## Domaine

Le nouveau support d’allocation accepte les équilibres réalisables à l’intérieur du polygone des quatre hélices, même lorsque la solution de norme minimale n’est pas positive. Cela ne crée pas d’autorité au-delà des capacités mécaniques. L’estimation de couple peut aussi absorber un défaut de modèle : elle ne prouve ni la position du centre réel ni la cause d’une perte d’autorité. Les tests de charge ne reproduisent pas les vrais joints/cordes Minecraft.

Le contrôleur standard est inchangé bit pour bit. Le profil quad reste expérimental. Les régressions ne sont pas masquées par le nombre de succès supplémentaires sur le banc de charge. Les [courbes complètes](README.md), [diagnostics transitoires](transients.json) et [contrôle 200/400 Hz](convergence/README.md) constituent des validations synthétiques ; aucun vol Minecraft n’a été effectué.

## Transitoires au-delà des critères finaux

Avec les mêmes bandes strictes du diagnostic de recherche (hauteur 0,3 m, assiette 2°, |Vy| 0,2 m/s, vitesse horizontale 0,3 m/s après déplacement), 329/552 traces retrouvent une stabilité durable en huit secondes au plus, contre 346/552 auparavant. 75 n’ont pas une seconde terminale entière dans ces bandes, contre 64 auparavant. Ces régressions sont conservées : le correctif cible le déplacement de charge, pas une amélioration uniforme de toutes les transitions. Les seuils ne sont pas des limites de vitesse en vol.
