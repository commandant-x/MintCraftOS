# Conclusions et prochaines corrections

**0/44 montages acceptés valident les 24 protocoles.** Quatre autres couples montage/contrôleur sont refusés avant activation. Le pilote 0.3.1 reste un prototype à domaine limité. Les fichiers de vol n’ont pas été modifiés pendant cette campagne.

## Ce que les mesures montrent

| Critère | Nombre de scénarios échoués |
| --- | ---: |
| transient_height | 648 |
| active_height | 393 |
| braking | 332 |
| active_attitude | 243 |
| final_speed | 215 |
| tail_speed_rms | 214 |
| tail_height_rms | 152 |
| tail_height_peak | 140 |
| tail_height_span | 135 |
| tail_tilt | 133 |
| motion | 97 |
| transient_tilt | 53 |
| active_vertical_rate | 51 |
| complete | 48 |
| recovery | 45 |

Un même scénario peut échouer à plusieurs critères : les nombres de ce tableau ne se somment pas en un total de vols. Un échec de seuil est distingué d’une divergence, d’un refus et d’un arrêt du calcul par les mesures et la raison détaillée.

Sur le quad rectangulaire de référence avec le profil rapide, le maintien, le démarrage à froid, la descente, l’avance, le recul et le freinage simple passent. Les diagonales, certains déplacements latéraux, les virages et la montée prolongée révèlent des dépassements transitoires ou des erreurs pendant la manœuvre. Une bonne stabilisation finale ne les efface pas.

Exemple mesuré : après la diagonale avant-gauche du profil rapide de référence, la hauteur dépasse la cible de 4,70 m. Au pic, l’erreur d’assiette est d’environ 1,94°. Le défaut vertical persiste donc alors que l’inclinaison demandée est assez bien suivie ; il faut traiter le couplage entre freinage, poussée et réponse des rotors, au-delà du seul gain d’assiette.

Les anciens 13 essais réussis couvraient des protocoles plus restreints et mesuraient surtout le maintien terminal, avec d’autres durées et réglages. Cette campagne applique aussi des exigences pendant chaque mouvement et publie les transitoires. Elle élargit la validation et ne transforme pas les anciens résultats en une preuve de stabilité générale.

## Priorités de travail issues de cette campagne

1. Préserver l’altitude pendant les inversions d’inclinaison et le freinage : vérifier la prédiction du régime, le débit local et la priorité collective de l’allocation sur les traces concernées.
2. Rendre les virages de trajectoire réalisables compte tenu de la vitesse et de la réponse d’assiette mesurées ; éviter de demander une direction que le véhicule ne peut pas suivre assez vite.
3. Réduire l’oscillation des montages à grande surface de voiles, faible inertie ou centre de masse décalé ; identifier séparément les limites de quantification et les erreurs de modèle.
4. Vérifier le suivi vertical lors des mouvements combinés et des variations de charge, sans modifier silencieusement la hauteur demandée.
5. Rejouer tous les mouvements après chaque correction. Une correction sur le maintien ne doit pas réintroduire une instabilité en diagonale ou au relâchement des touches.

Ces pistes restent des travaux à implémenter et à vérifier ; elles ne sont pas annoncées comme déjà corrigées par ce rapport. Une réponse dégradée ne prouve pas une panne mécanique précise.

## Sensibilité numérique

[Les huit comparaisons à 200/400 Hz](convergence/README.md) gardent la même classification, avec les amplitudes détaillées. Le pic de hauteur du virage rapide varie encore de plus d’un mètre ; ce contrôle ne constitue donc pas une preuve de convergence quantitative complète. Les deux variantes échouent au protocole concerné.

## Livraison

Les traces complètes, les courbes de chaque essai exécuté, les critères par mouvement et les sources gelées sont archivés séparément du logiciel de vol. Le TXT distribué reste inchangé : ces tests documentent ses limites, ils n’autorisent pas à annoncer un autopilote prêt pour tous les véhicules ou toutes les manœuvres.
