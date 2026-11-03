# Vitesse du quadrupède à pieds en slime

Objectif demandé : 10 blocs par seconde. Le robot conserve quatre pattes, trois axes par patte, quatre pieds en slime et un seul moteur créatif. **Cet objectif n'est pas atteint ni validé.** La campagne mesure la vitesse moyenne du châssis en direction de la piste ; les secondes sont des secondes de jeu à 20 ticks par seconde. Si le serveur ralentit, la vitesse en secondes réelles est plus faible.

[Télécharger le monde expérimental 16 tr/min](quadrupede-slime-16rpm.zip) · [Graphe Sputnik 16 tr/min](feedback-16rpm.clipboard.txt)

Le moteur est enregistré à l'arrêt et le graphe 16 tr/min est installé. Extraire `Quadrupede-Slime-16rpm/` dans `saves` de VENATOR 1.0.0 avec tous les mods et conserver `sublevels/`. Vérifier les douze récepteurs à 15, régler le moteur à 16 tr/min, puis cocher « Armer les commandes redstone » et « Lancer les huit mouvements » dans Sputnik. Décocher la seconde case avant une nouvelle séquence, puis désarmer et arrêter le moteur. Les séquences ne sont pas relancées automatiquement dans ce monde. Armer quand le robot est debout et orienté comme souhaité : sa pose de référence est alors capturée.

Après sauvegarde et redémarrage, le code et l'interface chargés correspondent aux fichiers livrés, les quatre pieds en slime et douze pivots étaient présents, et une nouvelle séquence a pu être lancée. Sur [ce second essai](16-reload/analysis.json), le robot a parcouru 10,17 blocs en 90 secondes de jeu, soit 0,113 bloc/s ; il est resté sous les seuils du banc. Ce résultat et les 0,177 bloc/s du premier essai montrent une variabilité importante. La sauvegarde 16 tr/min est une variante expérimentale ; le [monde 8 tr/min précédent](../spot-quadruped-slime-feet/quadrupede-pieds-slime.zip) reste disponible.

Sur le même monde de départ, les essais ont utilisé le graphe Sputnik, ses 13 récepteurs, un robot sans charge ni joueur et des relances de séquence effectuées par le banc. Les essais sont uniques ; les poses après rechargement peuvent différer. La piste est plane et comporte des obstacles, mais aucun essai ici ne prouve le franchissement complet du premier tapis ou des 250 blocs.

| Réglage | Résultat | Moyenne en Z | Limite observée |
| --- | --- | ---: | --- |
| [8 tr/min, référence](../spot-quadruped-slime-feet/slime-walk/analysis.json) | 9,50 blocs en 90 s | 0,106 bloc/s | Tenu sur la durée testée ; dérive latérale de 1,78 bloc |
| [16 tr/min, retour de cap](16rpm/analysis.json) | 15,90 blocs en 90 s | 0,177 bloc/s | Tenu sur la durée testée ; variation maximale de cap de 14,32° et dérive latérale maximale de 5,82 blocs |
| [32 tr/min, chronologie minimale](32rpm/analysis.json) | 7,65 blocs en 39,25 s | 0,195 bloc/s | Arrêt au seuil de 25° de changement d'orientation ; correction de cap non disponible dans ce réglage |
| [32 tr/min, correction de cap expérimentale](feedback32/analysis.json) | 14,54 blocs en 13,4 s | 1,085 bloc/s | Arrêt au seuil de 25° de changement d'orientation ; vitesse non stable |
| [64 tr/min, chronologie 32 tr/min](64rpm/analysis.json) | 12,58 blocs en 11,8 s | 1,066 bloc/s | Arrêt au seuil d'orientation après soulèvement ; vitesse non stable |
| [128 tr/min, plafond d'origine](128rpm/analysis.json) | 0,33 bloc en 2,7 s | 0,121 bloc/s | Garde d'inclinaison Sputnik déclenché en jeu, le banc coupe ensuite le moteur |
| [256 tr/min, plafond d'origine](256rpm/analysis.json) | 0,33 bloc en 2,7 s | 0,121 bloc/s | Même limite de pivot ; garde d'inclinaison déclenché |

Le réglage à 16 tr/min utilise des impulsions d'aller et de retour égales en nombre de ticks et maintient une correction de cap quantifiée. À 32 tr/min, les impulsions atteignent la résolution d'un tick ; la variante avec correction modifie la chronologie des hanches mais n'a pas gardé son cap suffisamment longtemps. Sur chaque trace, pas plus d'un pignon d'articulation tournait au même tick. Les temps et vitesses avant un arrêt ne constituent pas une vitesse stable. La meilleure progression mesurée sur une seconde dans l'essai 32 tr/min avec correction est d'environ 2,41 blocs, et ne démontre pas une vitesse soutenue.

## Plafond des pivots

Le mod Simulated limite la consigne des roulements `swivel_bearing` à `max_swivel_bearing_speed` : la configuration initiale était de 96 tr/min. Le banc instrumenté a mesuré les **variations de consigne d'angle**, pas les angles mécaniques effectifs :

| Limite / moteur | Consigne maximale enregistrée par tick | Résultat |
| --- | ---: | --- |
| [96 / 128 tr/min](cap96-128rpm/analysis.json) | 28,8° | Garde d'inclinaison après 2,7 s |
| [256 / 128 tr/min](cap256-128rpm/analysis.json) | 38,4° | Garde après 4 s, soulèvement du châssis |
| [256 / 256 tr/min](cap256-256rpm/analysis.json) | 76,8° | Garde après 1 s, mouvement vers l'arrière |

La configuration a été relevée uniquement pour les copies de test puis remise à sa valeur initiale de 96 tr/min. Relever ce plafond sans revoir la mécanique ou la commande ne démontre pas de marche rapide et stable.

Le garde logiciel ferme les embrayages lorsque la pose est invalide ou que la variation de tangage ou de roulis depuis l'armement dépasse 12°. Les essais 128 et 256 tr/min montrent son déclenchement en jeu ; le **banc**, séparément, arrête le moteur. Le Lua ne coupe pas le moteur et une perte de liaison peut engager un embrayage : il ne s'agit pas d'un arrêt de sécurité matériel.

Sources des variantes : [16 tr/min avec retour de cap](feedback-16rpm.lua), [32 tr/min avec retour de cap](feedback-32rpm.lua) et [chronologie minimale](guard-32rpm-and-higher.lua). Les graphes à importer et les mesures sont expérimentaux, non qualifiés pour une marche continue ni un parcours d'obstacles.
