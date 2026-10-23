# Autopilot Ascendancy — travail actif après 0.18.90

Objectif utilisateur : finir le périmètre du document joint le 23 octobre 2026,
26979 octets, en suivant A → B → C → D → E. Ce fichier n'annonce pas une livraison
achevée. La version 0.18.89 livre un incrément qualifié du lot A, décrit dans
[le compte rendu A.9](ASCENDANCY-A9-MEASURED-CONTROL.md). Les lots A–E restent
l’objectif actif ; la livraison ne signifie pas la fin du projet.

## A — mesures et contrôle

Travail local : caractérisation des seules sorties affectées, neutre physiquement
stable, observations six axes après retours RX confirmés, modèle couplé et borné
au domaine réellement mesuré, faisabilité bidirectionnelle, quantification couplée
sur 16 niveaux, essais montée/descente/retour ou rotations avant maintien local.
`flightd` reste le seul auteur des sorties. L'activation automatique peut utiliser
cette voie lorsqu'aucun brûleur ou drivetrain collectif n'est configuré ; un neutre
de sustentation inconnu reste un refus expliqué. Les preuves ne sont jamais des
booléens reçus d'un client.

Tests locaux nouveaux : `response-model`, `measured-controller` (neuf modèles
physiques simplifiés), `known-output-flight` (commandes, dérivées de pose, vraie
qualification, maintien local et STOP), `selected-feedback` (provenance séparée).
Ce ne sont pas des essais Minecraft réels.

Bridge en développement 0.3.0 : lecture sélectionnée de 1 à 64 nœuds déjà inventoriés
du parent chargé, limitée dans le temps et globalement ; pas de rescans complets,
aucune écriture ni chargement de chunk. Le cache géométrique demeure indépendant.
La compilation et les tests Java passent contre les JAR installés, notamment
Sable 2.0.6. Le JAR 0.3.0 et son SHA-256 sont livrés ; les tests Java passent.

Implémentés localement : stratégie d'inclinaison mesurée passivement, qualification
X/Z distincte, boucles séparées selon stabilisation mesurée, surveillance de
convergence et d'oscillation. Restent notamment : commissioning universel depuis
un neutre inconnu, qualification en jeu, freinage évolutif,
interface native complète du nouveau contrôleur et protocole de qualification
Minecraft. Le maintien local et ses diagnostics sont intégrés à Control/Calibration.

## B — réutilisation et adaptation

L'ancien trim aérien reste intact. Le nouveau maintien local possède une correction
intégrale bornée, sans balayage automatique, et suspend l'horizontal après une
variation de masse. Il ne transforme pas cela en certificat de recalibration.
Le rapport de réponse possède un stockage transactionnel borné et une provenance
explicite. B.1 ajoute la réutilisation après nouveau relevé et vrais essais,
le contrôle d’inertie/COM, les liaisons chauffe/moteur indépendantes et un
archivage de schéma séparé. Restent : réutilisation plus fine après changements
structurels localisés, adaptation passive qualifiée des réponses horizontales et
du freinage ; aucune recertification par simple trim. Pas de réarmement au redémarrage.

## C — terrain et planification

À développer : lecture de terrain réellement chargé avec dimension et permission,
cache Atlas borné, volume du véhicule, inconnu/âge/incertitude, planification 3D
compatible avec les vitesses/freinages mesurés, contrôle de chaque segment et
recalcul. La coque du véhicule ne sera jamais utilisée comme obstacles du monde.

## D — phases de vol

À développer : transitions explicites et prises de décision physiques pour
prévol/décollage/montée/croisière/approche/maintien/dégradation/secours. Aucun
atterrissage automatique n'est disponible sans observations probantes de surface,
dégagement, vitesse et contact. Les capteurs manquants doivent être diagnostiqués.

## E — missions

À développer : routes enregistrées, progression, pause/reprise contrôlée, retour,
rapports, autorisation de mission détachée explicite. La fermeture reste STOP
par défaut et le rendu ne possède aucune autorité d'actionnement. Le redémarrage
ne restaure jamais des sorties actives.

## Livraison et limites globales

Régénérer l'installateur et tester sources, modules installés, Cobalt, sauvegarde,
interruptions, rollback, 1 000 000 octets avec 100 000 octets de données utilisateur.
Fournir le nouveau JAR et son SHA-256 si Java évolue, sans modifier automatiquement
les mods du serveur. Publier main et la branche de travail puis vérifier les octets
raw GitHub. Le document utilisateur exige de signaler les essais Minecraft non
réalisés ; aucun monde n'est disponible ici et aucune autonomie complète en jeu
ne peut être annoncée sur la seule simulation.
