# Méthode et limites de la campagne

Cette campagne teste les **quadricoptères à quatre commandes indépendantes de sustentation**. Elle ne certifie pas les autres architectures de l'autopilote. Le scénario `paired-rotors` comporte deux moteurs identiques derrière chaque commande : huit moteurs physiques, quatre degrés de commande, sans inventer huit commandes indépendantes.

Seul le profil rapide corrigé 0.3.3 est exécuté ici ; le contrôleur standard reste inchangé. L’empreinte du contrôleur est gelée au lancement. Les modèles physiques, protocoles et critères sont également gelés ; aucun réglage du pilote ni assouplissement des critères n'est appliqué pendant la campagne. Le JAR Cosmonautics 26.08.307 est vérifié par son SHA-256 avant extraction de son interpréteur LuaJ. Le code ne commande aucun vrai véhicule.

## Mécanique indépendante

- Corps rigide 6D : quaternion normalisé, position/vitesse monde et vitesse angulaire dans le repère corps, intégrés à 200 Hz.
- Gravité 11 m/s² ; traînée linéaire 0,2/s sur la vitesse relative au vent et traînée de rotation 0,05/s. Ces traînées sont des hypothèses de banc, pas des mesures du serveur.
- Poussée de l'hélice : loi auditée Aeronautics/Simulated 1.3.2, pression Sable 2.0.6 interpolée depuis l'oracle Java conservé dans le dépôt. Poussée locale calculée au point d'application, avec la vitesse due à la rotation du châssis et le vent.
- Transmission : commandes entières 0–15 ; 0 transmet le régime source entier, 1–15 suivent `(15-signal)/16`. La montée en régime et les retards sont simulés indépendamment de l'estimateur du pilote.
- Inertie réelle : tenseur symétrique défini positif. Le cas `coupled-inertia` a des termes croisés ; l'observation Sputnik ne fournit que la diagonale. Le solveur physique conserve les termes croisés et le couple gyroscopique du **châssis**.
- Les inerties des géométries synthétiques, sauf valeurs explicites de référence et de stress, proviennent d'une distribution déclarée : moitié de la masse sur les bras, moitié dans le corps central. Elles ne proviennent pas d'un scan Minecraft.
- Un équilibre initial nominal est résolu **indépendamment du contrôleur** pour la somme des forces et les moments X/Z, y compris sur un montage asymétrique. Les écarts physiques cachés — centre de masse déplacé, moteur affaibli, pression erronée — restent des perturbations délibérées de cet équilibre. Le démarrage à froid commence à zéro RPM.
- Charge suspendue : masse ponctuelle, câble unilatéral, inertie du corps prise en compte au point d'attache, projection de dérive de longueur/vitesse. Le pilote ne reçoit ni la masse de la charge ni sa longueur. Ce modèle ne reproduit pas fidèlement les joints du serveur.

Le calcul serveur du contrôleur est appelé à 20 Hz. Les traces conservent **chaque appel**, avec commandes, RPM physiques, assiette réelle/cible, altitude réelle/cible, vitesses et résidu. L'encodage des nombres conserve neuf chiffres significatifs ; sa précision est testée dans le LuaJ réel. Les critères portent sur ces traces, les RMS sont calculées sur toutes les observations de leur fenêtre.

## Phases et exigences

La préparation précède 5 s ; la commande principale dure de 5 à 10 s. Les inversions et cycles verticaux ajoutent une seconde phase documentée. Le retour à la stabilité est évalué sur les dix dernières secondes, sans que le temps écoulé suffise à faire réussir une mesure. Un mouvement doit présenter un déplacement signé, une vitesse inversée ou une courbure réellement observés. Les critères et protocoles complets sont dans `campaign.json` et le rapport principal.

Les seuils communs d'assiette en mouvement utilisent l'**erreur par rapport à l'inclinaison demandée** ; une inclinaison commandée de 20° n'est pas un échec en elle-même. En maintien final, l'assiette doit en revanche revenir sous 5°. Les mouvements verticaux exigent un suivi de vitesse verticale, en plus du maintien final. Les trajectoires de virage sont évaluées par la vitesse monde ; aucune autorité de lacet du nez n'est inventée.

Les résultats sont `PASS`, `FAIL` ou `REFUSED`. Un refus avant activation n'est pas une stabilisation validée. Une faute de télémétrie ou une sortie de l'enveloppe du banc fait échouer le scénario. L'enveloppe d'essai comporte un sol déclaré à Y=0, une atmosphère limitée à Y=315 et une distance horizontale maximale de 5 000 m pour arrêter une divergence numérique ; ces bornes ne sont pas ajoutées au pilote distribué.

## Ce qui reste hors validation

Pas de collision, de coque scannée, de réseau de stress, de sol/contact, d'effet de sol ni de couple gyroscopique propre aux hélices. La charge pendulaire n'est pas un véritable joint Minecraft. Les imperfections de capteurs sont des scénarios déterministes, pas une étude probabiliste représentative de tous les serveurs. Le temps réel de calcul du banc ne garantit pas une cadence de 20 Hz dans le jeu. Une réussite synthétique ne constitue pas une qualification de vol dans Minecraft.

La distribution de vol et ses TXT restent inchangés pendant cette campagne. Les archives lourdes de résultats sont séparées de l'archive de vol, qui reste sous un mégaoctet.

Dans les traces, `pitch`/`roll` sont les observations d'attitude fournies au contrôleur, avec le bruit déclaré. `tilt` et `attitude_error` sont calculés depuis l'état physique indépendant ; les critères d'assiette s'appuient sur ces derniers. Les positions/vitesses tracées sont également l'état physique, tandis que les éventuels bruit/retard d'observation sont appliqués à l'entrée du contrôleur. Le bruit testé concerne explicitement la position et les angles, pas tous les défauts possibles d'un capteur réel.

## Comparaison 0.3.2 / 0.3.3

Les mêmes 24 fixtures, 24 mouvements, paramètres mécaniques et critères historiques sont conservés à 20°. Les deux versions utilisent 256 RPM. L'analyse de transition durable est ajoutée séparément sans modifier ces critères. Les traces et courbes de la version précédente restent immuables. Voir FINDINGS.md pour les 9 améliorations et 8 régressions des anciens critères.
