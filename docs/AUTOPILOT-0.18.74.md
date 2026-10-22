# Autopilote automatique — 0.18.74 / Bridge 0.2.3

Mettre à jour MintCraftOS depuis CraftOS :

```lua
wget run https://raw.githubusercontent.com/commandant-x/MintCraftOS/main/install.lua
```

Remplacer l'ancien JAR Vehicle Bridge par
`addons/vehicle-bridge/dist/mintcraft-vehicle-bridge-1.21.1-0.2.3.jar` dans les mods
du serveur et des clients, puis redémarrer Minecraft. Une seule version du bridge.

## Utilisation

Ouvrir Navigation et cliquer **Autopilot / Activate autopilot** sur Flight, Route,
Altitude ou Control. Sur un petit écran, Flight affiche **Pilot**. Confirmer la
zone dégagée et les essais de mouvement, puis laisser Navigation ouverte.
La progression et le motif précis d'un blocage apparaissent dans Altitude.

La préparation se charge de :

1. vérifier identité, permissions, pose, commandes physiques et inventaire ;
2. relever la structure chargée sans charger de chunks ;
3. créer le groupe de brûleurs si une fréquence existante commune et un émetteur
   unique sont identifiés ; conserver tout mapping déjà configuré ;
4. identifier les deux chaînes moteur si leurs sources Create relient réellement
   chaque propulseur aux clutch, transmission et inverseur, avec un RX adjacent
   unique pour chaque commande ;
5. initialiser les brûleurs et vérifier les signaux reçus, y compris le secours ;
6. mesurer les hauteurs stables si nécessaire ou revalider une table sauvegardée ;
7. vérifier en mouvement le maintien, montée/descente, retour, secours et STOP ;
8. mesurer les deux moteurs et tester un court trajet lorsque configurés ;
9. activer le maintien à l'altitude de départ si elle est dans la plage mesurée,
   sinon à la limite la plus proche de cette plage.

Le maintien d'altitude n'invente pas de destination. Pour voyager, choisir les
points dans Route et confirmer le trajet. Aucun atterrissage ni évitement
automatique d'obstacles n'est ajouté.

## Réutilisation des mesures

Le rapport de calibration schéma 2 remplace le précédent dans
`/system/config/navigation-calibration.cfg`, sans historique permanent. Le boot ne
restaure jamais un état armé. Une activation confirmée est toujours nécessaire.

La table est candidate seulement si le véhicule, les fréquences/senseurs/moteurs,
la structure SHA-256 complète du plot chargé et l'unité de masse correspondent,
avec une différence de masse au plus de 2 %. Le modèle enregistré est validé et
les retours électriques et essais de maintien/secours sont refaits. Cela évite les
neuf paliers du sweep lorsque le vaisseau n'a pas changé.

Pour les moteurs, les courbes précédemment mesurées sont candidates. Quatre
mesures fraîches testent avant/arrière pour chaque groupe, puis comparent les
accélérations longitudinales, le lacet et le freinage. Une différence hors tolérance
(35 % + petite marge absolue pour accélération/lacet, freinage > max(0,5 m, 1,5 fois
l'ancien)) déclenche automatiquement les 60 mesures complètes. Un court trajet
réel valide ensuite le guidage. Le rapport distingue les 60 mesures de référence
conservées des quatre contrôles frais ; il ne prétend pas que les 60 viennent
d'être refaites. Un défaut de communication arrête la procédure.

Un changement de structure ou de mapping reprend la mesure complète. Un ancien
bridge sans empreinte ou un scan partiel interdit la réutilisation, sans empêcher
une calibration complète avec les inventaires brûleurs/RX nécessaires.

L'empreinte ignore seulement les propriétés de fonctionnement `powered`, `power`
et `lit`. Elle conserve identifiants, orientation et autres propriétés des blocs,
leurs positions et les sections. Le relevé reste paginé et non atomique : refaire
l'activation après une modification du montage. Les enfants Sable et contraptions
mobiles ne sont pas inclus et ne sont pas couverts par cette empreinte.

## Retours mécaniques et limites de découverte

Bridge 0.2.3 exporte pour au plus 1024 entités cinétiques chargées : RPM signés
réels, RPM théoriques, surcharge, source de rotation, position et rôle reconnu.
Les RPM viennent des getters Create ; 256 RPM n'est pas utilisé comme mesure.
Ces données sont consultables dans Equipment. Aucune écriture mécanique ni
modification de la physique n'est ajoutée au bridge.

Une chaîne inactive peut avoir perdu sa source Create ; plusieurs RX ou chemins
peuvent aussi rendre le montage ambigu. Dans ce cas, l'automatisme s'arrête avec
un motif et demande l'affectation **une seule fois** dans Motor links. Il ne choisit
pas le moteur le plus proche et ne teste pas des fréquences inconnues au hasard.
Le rôle gauche/droite est nommé depuis X du plot ; la réponse au lacet est ensuite
mesurée, sans déduire le guidage de ce nom.

F10, STOP, fermeture, permission retirée, changement d'identité, retour absent ou
pose périmée annulent aussi la préparation avant le premier signal. Après un STOP
terminé, une nouvelle activation confirmée peut acquitter l'état arrêté et relancer
les vérifications. Aucun interrupteur physique indépendant n'est certifié par le
logiciel ; ses indicateurs restent non validés sans essai réel.

## Vérifications

Tests Lua de bout en bout avec plante simulée : activation après redémarrage,
reprise sans sweep, quatre contrôles moteurs frais, trajet réel dans la simulation,
changement d'empreinte, STOP et fermeture. Tests de modèles corrompus, chaînes
sources ambiguës/cycliques et getters mécaniques invalides. Tests Java SHA-256,
propriétés structurelles/de fonctionnement et contrat sans mutations. Validation
Minecraft avec le montage réel encore nécessaire.

Résultat de livraison : 157 suites Lua sur source et paquet compact, plus contrôles
ciblés des derniers ajustements, et 12 tests Java réussis. Installation testée à
environ 882 Ko avec 100 Ko de données personnelles, pic de migration depuis
0.18.73 inférieur à 975 Ko sur quota 1 000 000 octets. La place est toujours vérifiée
avant écriture. Le rapport de calibration compact de la simulation mesure environ
37 Ko ; un disque plus rempli peut conserver la preuve en RAM sans pouvoir sauver
le rapport, ce qui impose une nouvelle mesure au prochain démarrage.

## Correctif 0.18.75 : capacités partielles

Un seul brûleur suffit pour le maintien d'altitude. Zéro ou un propulseur,
ou des chaînes moteur ambiguës, ne bloquent plus les tests verticaux. Les mappings
moteurs sont conservés mais désactivés lorsqu'un propulseur unique est détecté ;
aucune commande gauche/droite n'est fabriquée. Le pilotage horizontal autonome
reste indisponible tant que son autorité n'est pas mesurée. L'interface distingue
les deux capacités au lieu de refuser toute activation.

Les doublons hérités d'une même fréquence collective de brûleurs sont fusionnés
si endpoint, limites, secours et mix altitude correspondent. Un canal de commande
peut piloter un seul brûleur ; ce n'est pas une exigence de deux brûleurs.
