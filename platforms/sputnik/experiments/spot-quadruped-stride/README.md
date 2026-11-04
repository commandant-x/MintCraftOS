# Marche corrigée en direction : essais

Prototypes pour le quadrupède à un moteur, quatre pieds en slime et douze articulations. Le script mesure la position et l'orientation Sputnik et adapte les impulsions de hanche ; il ne mesure ni le contact des pieds ni les angles physiques des articulations. Les périodes d'ouverture et de retour de chaque hanche sont appariées.

Dans Minecraft, sur une copie du même monde et à 20 ticks par seconde de jeu :

| Moteur | Résultat | Vitesse moyenne longitudinale | Observation |
| --- | --- | --- | --- |
| 16 tr/min | 13,54 blocs en 90 s de jeu | 0,150 bloc/s | déplacement latéral maximal 3,44 blocs ; aucun franchissement de la première bande établi |
| 24 tr/min | arrêt après 18,3 s de jeu | 0,527 bloc/s avant arrêt | écart d'orientation de 25,13° ; essai interrompu pour stabilité |

Ce sont des essais uniques, avec une position initiale rechargée et un tassement physique possiblement différent ; ils ne prouvent pas une amélioration statistique. Les 10 blocs/s et le parcours de 250 blocs restent à atteindre. Les vitesses de jeu ne sont pas nécessairement des vitesses réelles si le serveur ralentit. Les traces et analyses sont dans les répertoires `lane-16rpm` et `lane-24rpm` ; `SpotQuadrupedStrideProbe-tested.java` est le banc exact de ces essais.
