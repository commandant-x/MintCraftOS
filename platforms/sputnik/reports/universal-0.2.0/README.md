# Autopilote Sputnik 0.2.0 — résultats

Référence : **49/50**. Stress : **5/12**. Changement de masse avec réponse dégradée : **2/2**.

**Le code Lua livré est exécuté dans LuaJ de Cosmonautics. La mécanique est une plante synthétique indépendante, pas une copie mesurée du véhicule Minecraft.**

Les sources, le programme mécanique et les CSV sont vérifiés par empreinte avant agrégation. Une exécution travaille dans un dossier privé et verrouille sa destination. Les résultats incomplets ou provenant d'un autre contrôleur sont refusés.

| Série | Réussites | Domaine |
| --- | ---: | --- |
| [profile-1](profile-1/README.md) | 10/10 | Quad à petites hélices |
| [profile-2](profile-2/README.md) | 9/10 | Ballon avec gouverne dépendante du mouvement |
| [profile-3](profile-3/README.md) | 10/10 | Venator, 4 sustentations et 2 banques de 2 moteurs |
| [profile-4](profile-4/README.md) | 10/10 | Hélicoptère, sustentation centrale + propulsion + couple de lacet déclaré |
| [profile-5](profile-5/README.md) | 10/10 | Quad modulaire asymétrique, 8/12/16/20 voiles |
| [low-inertia-delay](low-inertia-delay/README.md) | 3/6 | Inerties ×0,25, retard 2 ticks, bruit position 0,01 m |
| [offset-weak-rotor](offset-weak-rotor/README.md) | 2/6 | COM réel décalé de 0,5 m et rotor 1 à 70 % du modèle dès le départ |
| [mass-damage](mass-damage/README.md) | 2/2 | À 6 s : masse −12,5 %, COM décalé de 0,5 m et rotor 1 à 70 %, depuis un maintien initial connu |

Les dix cas de référence sont maintien, changement de hauteur, avance, recul, virage, changement de masse, calibration, mission courte, mission rectiligne et déplacement maintenu 20 s. La mission rectiligne part de la position réellement atteinte après calibration ; elle ne remplace pas le cas court plus contraignant.

Critères : absence de défaut, erreur finale de hauteur < 1 m, inclinaison maximale < 25°, vitesse finale < 0,3 m/s et RMS de vitesse sur les 10 dernières secondes < 0,35 m/s. Les déplacements doivent réellement parcourir > 0,2 m ; le lacet doit être observé si disponible. La calibration et la mission doivent se terminer pour réussir leur cas. Pour le déplacement prolongé du quad : inclinaison moyenne > 6° et dispersion < 1,5°. Les excursions transitoires sont publiées séparément ; une erreur maximale inclut les changements demandés de consigne.

L'arrivée est un maintien, pas un atterrissage. Le ballon à gouverne n'est pas qualifié pour les routes serrées qui échouent. Un maintien réussi ne qualifie pas tous les virages. Les inerties, le coefficient de gouverne et les réponses linéaires sont des hypothèses explicites du banc. Les valeurs zéro d'un cas REFUSED indiquent que la plante n'a pas été démarrée, pas une excursion mesurée nulle.

Les tests du graphe natif couvrent séparément OFF physique, absence de réarmement, cible modifiée sans réinitialisation, doublons, montage figé, héritage des sorties, coupure, mise en repli continue et sérialisation SNBT/NBT réelle. Voir `validation.log`.

## Échecs conservés

- profile-2 / mission : FAIL ; erreur finale hauteur 1.002 m, inclinaison maximale 0.00°, vitesse finale 0.014 m/s.
- low-inertia-delay / hover : FAIL ; erreur finale hauteur 2.267 m, inclinaison maximale 25.98°, vitesse finale 1.832 m/s.
- low-inertia-delay / forward : FAIL ; erreur finale hauteur 11.288 m, inclinaison maximale 23.50°, vitesse finale 1.846 m/s.
- low-inertia-delay / mass : FAIL ; erreur finale hauteur 12.279 m, inclinaison maximale 25.76°, vitesse finale 1.802 m/s.
- offset-weak-rotor / hover : FAIL ; erreur finale hauteur 0.000 m, inclinaison maximale 5.75°, vitesse finale 0.789 m/s.
- offset-weak-rotor / forward : FAIL ; erreur finale hauteur 0.015 m, inclinaison maximale 12.37°, vitesse finale 0.796 m/s.
- offset-weak-rotor / hover : FAIL ; erreur finale hauteur 0.187 m, inclinaison maximale 4.00°, vitesse finale 0.305 m/s.
- offset-weak-rotor / forward : FAIL ; erreur finale hauteur 0.064 m, inclinaison maximale 12.38°, vitesse finale 0.346 m/s.

## Reproduire

```sh
python3 tools/build-sputnik.py
python3 tools/test-sputnik-universal.py --cosmonautics-jar /chemin/cosmonautics-26.08.307.jar --java-home /chemin/jdk21 --profiles 1 --output /tmp/quad-test
python3 tools/report-sputnik-universal.py
```

Exécuter les cinq profils et les deux jeux de stress et le changement de masse avec réponse dégradée dans leurs dossiers respectifs avant agrégation. Les paramètres exacts sont dans chaque `summary.json`. Les JAR audités ne sont pas redistribués.
