# Quadrupède inspiré de Spot : transmission à un seul moteur créatif

Objectif : un robot à quatre pattes inspiré de Spot, construit dans Minecraft et animé par **un seul moteur créatif Create**. Les autres composants distribuent ou commandent cette puissance : aucun autre moteur créatif n'est prévu. La forme et les performances de Spot ne sont pas encore reproduites.

Le premier banc construit sur Minecraft 1.21.1 / NeoForge 21.1.264 avec les mods VENATOR est **fixe, sans pattes ni charge de marche**. Il comporte un moteur créatif réglé à 64 tr/min, un arbre principal, quatre boîtes d'engrenages et quatre embrayages Create commandés individuellement par leviers. Il ne teste pas encore les signaux Sputnik ni les articulations.

```text
        moteur créatif unique (64 tr/min)
                        │
             arbre de transmission
          ┌──────┬──────┼──────┐
      embr. 1 embr. 2 embr. 3 embr. 4
          │      │      │      │
      arbre 1 arbre 2 arbre 3 arbre 4
```

Les mesures natives ([CSV](measurements.csv), [validation](validation.json)) montrent :

| Situation | Moteur | Branche 1 | Branche 2 | Branche 3 | Branche 4 |
|---|---:|---:|---:|---:|---:|
| Toutes branchées | 64 | 64 | -64 | 64 | -64 |
| Branche 1 coupée | 64 | 0 | -64 | 64 | -64 |
| Branche 2 coupée | 64 | 64 | 0 | 64 | -64 |
| Branche 3 coupée | 64 | 64 | -64 | 0 | -64 |
| Branche 4 coupée | 64 | 64 | -64 | 64 | 0 |
| Toutes rétablies | 64 | 64 | -64 | 64 | -64 |

Vitesses en tours/minute ; le signe reflète le sens observé sur chaque axe. Ces résultats vérifient l'isolement individuel des quatre branches dans ce montage à vide. Ils ne démontrent ni couple disponible sous charge, ni réglage d'angle indépendant, ni inversion commandée, ni stabilité ou marche. Les sens alternés devront être intégrés aux renvois et aux articulations.

Pour construire l'animal, il reste à développer les quatre jambes articulées, leurs courses et fins de course, un mécanisme de commande de position alimenté par cet arbre unique, la synchronisation des appuis, l'équilibre et les commandes Sputnik. Les [phases abstraites expérimentales](../walkers/README.md) ne sont pas un contrôleur de pattes prêtes à brancher.

La source du banc est [`SpotTransmissionProbe.java`](../../../../tools/minecraft-world-test/spot/SpotTransmissionProbe.java) ; son empreinte et celle du JAR testé sont conservées dans [provenance.json](provenance.json). `python3 tools/minecraft-world-test/spot/check_transmission.py CHEMIN_CSV` contrôle les six observations. Le fixture utilise un serveur jetable ; la fin du processus ne suffit pas à déclarer l'essai réussi.
