# Corrections 0.3.2 et comparaison FPV

**393 PASS / 159 FAIL / 24 REFUSED** sur 576 cellules. Le maintien sans touche réussit sur les 23 configurations acceptées. Seules la référence et la variante à tenseur d’inertie couplé réussissent les 24 mouvements. Ce résultat ne valide pas tous les montages, ni le vol Minecraft.

Le même ensemble FPV en 0.3.1 donnait 158 PASS, 346 FAIL et 72 REFUSED. Les critères et les paramètres du banc sont conservés ; seule l’inclinaison est rendue explicite à 20°, sa valeur antérieure. Le contrôleur standard n’est pas modifié ni réévalué ici.

| Ancien résultat | Nouveau résultat | Nombre |
| --- | --- | ---: |
| FAIL | FAIL | 144 |
| FAIL | PASS | 202 |
| PASS | FAIL | 9 |
| PASS | PASS | 149 |
| REFUSED | FAIL | 6 |
| REFUSED | PASS | 42 |
| REFUSED | REFUSED | 24 |

Les 42 passages REFUSED → PASS correspondent aux hélices petites/mixtes nouvellement exercées. Ils ne sont pas confondus avec les 202 passages FAIL → PASS. **Neuf anciennes réussites deviennent des échecs** ; la livraison n’est donc pas une amélioration uniforme sur toute la matrice.

## Ce qui change réellement dans Sputnik

- Allocation normale à priorité collective : une demande de tangage/roulis irréalisable est réduite avant de sacrifier la sustentation réalisable. La récupération conserve une priorité de moments distincte.
- Calcul de réponse par rotor et référence ajustée au rotor le plus lent ; petites hélices, modulaires et tailles différentes partagent le même contrat.
- Compensation répartie du débit local ; observateur passif de couple sans nouvelle saisie du poids ou de la corde.
- Virage de trajectoire fondé sur la vitesse observée, avec courbure liée à la réponse mécanique. Aucun lacet du nez ni plafond de vitesse inventé.
- Freinage vertical rapide conservé après relâchement, suspendu durant une récupération. Réacquisition de la vitesse angulaire ambiguë près d’un demi-tour.
- Défaut de descripteur associé au numéro du moteur et au formulaire.

## Référence : résultats et limites

24/24 mouvements réussis à 20° ; les translations horizontales ont un pic transitoire de hauteur de 0,64–0,68 m. Le maintien sans touche a une excursion finale crête-à-crête de 0,014 m. Les montées/descentes ont encore des erreurs transitoires allant à 1,90 m : « PASS » ne signifie pas une altitude constante pendant toute commande verticale.

La récupération inversée perd **10,39 m** et se stabilise en **6,45 s** dans ce banc. Les freinages horizontaux de référence demandent environ **3,75–5,05 s**, selon le mouvement. Ce correctif n’établit pas encore une réponse aussi rapide qu’un drone FPV réel.

Le test exploratoire de référence à 25° donne 22/24 : latéral gauche/droite dépassent les seuils transitoires (environ 6 m de hauteur et 56° d’inclinaison). Le défaut livré revient à 20° ; la consigne reste modifiable jusqu’à 45°, avec des essais supplémentaires nécessaires. Les résultats et traces 25° sont dans [inclination-25](inclination-25/README.md).

## Régressions et travaux ouverts

| Configuration | Mouvement auparavant réussi | Critères échoués |
| --- | --- | --- |
| light-16kg | descend-left | transient_height |
| light-16kg | recovery-diagonal | final_speed |
| paired-rotors | descend-left | transient_height |
| paired-rotors | recovery-diagonal | final_speed |
| slow-radio | recovery-diagonal | tail_tilt, tail_speed_rms, final_speed, recovery |
| wide | forward | transient_tilt |
| wide | reverse | transient_tilt |
| wide | descend-left | transient_height |
| wide | brake | transient_tilt |

Les retards radio de trois/cinq ticks, les très faibles inerties, la poussée surdimensionnée et certains montages larges restent particulièrement difficiles en mouvement. La configuration sans réserve verticale est refusée ; ce refus ne compte jamais comme maintien réussi. Les hélices mixtes passent le maintien, mais seulement 19/24 mouvements : ne pas les annoncer qualifiées.

## Fidélité et livraison

La vérification 200/400 Hz porte sur quatre mouvements de référence : [convergence](convergence/README.md). Ce contrôle de sensibilité ne remplace pas un solveur Minecraft fidèle. Les rapports lourds sont exclus du ZIP de vol. Les sources, tests natifs et TXT complet sont livrés en 0.3.2 ; aucun vol réel n’a été effectué.
