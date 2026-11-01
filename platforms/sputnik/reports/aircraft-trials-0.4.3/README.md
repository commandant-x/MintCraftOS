# Prototypes manquants et captures Minecraft

Les six [captures du jeu](screenshots/) représentent les constructions du banc 0.4.2 : tricoptère, quad, hexacoptère, octocoptère, quad à propulsion auxiliaire et ballon vertical. Elles ont été prises dans le client Minecraft 1.21.1 avec les mods VENATOR, dans des copies des mondes livrés ; la caméra spectateur a été déplacée et l'heure réglée pour le cadrage. Les constructions sont des bancs fonctionnels simples, pas des modèles décoratifs. Les captures ne sont pas des essais de vol.

## Hélicoptère tandem expérimental : échec

Un montage avec deux rotors porteurs alignés a été construit sur le serveur natif puis libéré en altitude après armement. Il passe en mode dégradé : son roulis passe d'environ 2° au tick 340 à 49,9° au tick 420 et 84,9° au tick 444. Le banc interrompt l'essai et verrouille l'engin. Aucun maintien stable ni décollage depuis le sol n'est validé. Le contrôleur et le montage exigent un moyen effectif de contrôler le roulis ; deux rotors fixes alignés ne l'assurent pas dans ce test. Géométrie, sources exactes, configuration et [trace](helicopter-tandem/) sont archivées.

## Prototype avion : refus d'armement

Un prototype avec ailes `createpropulsion:wing` et une hélice de propulsion a été assemblé dans le même environnement. Le contrôleur actuel affiche « Sustentation requise » et ne s'arme pas : le banc s'arrête au tick 300 avant toute libération. Aucun roulage, décollage ni vol sur ailes n'a été testé. Le résultat montre que ce contrôleur attend une sustentation disponible au démarrage ; une commande adaptée au décollage sur ailes reste à développer et à valider. Voir les [mesures et traces](plane-prototype/).

## Travail restant

Un contrôleur et un montage capables de stabiliser un hélicoptère, le vol complet sur ailes, les gouvernes, et un V22 avec nacelles orientables et transition n'ont pas été livrés ni validés. Les deux prototypes ci-dessus sont des essais exploratoires, pas des appareils prêts à voler. Les résultats précédents des multicoptères et du ballon se trouvent dans [le rapport 0.4.2](../native-fleet-0.4.2/README.md) et [la campagne de vitesse](../speed-envelope-0.4.3/README.md).
