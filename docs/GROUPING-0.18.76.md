# Groupage automatique — 0.18.76

Mettre à jour le Computer puis redémarrer :

```lua
wget run https://raw.githubusercontent.com/commandant-x/MintCraftOS/main/install.lua
```

Le Vehicle Bridge **0.2.3** reste compatible. Dans Navigation, cliquer **Activate
autopilot** et confirmer la zone dégagée. Le tableau Altitude affiche les groupes,
les fréquences et les identifiants des membres détectés.

## Brûleurs

Les brûleurs dont les récepteurs adjacents portent la même paire d'items/couleurs
forment un groupe de fréquence. Plusieurs récepteurs adjacents identiques ne sont
pas une ambiguïté ; plusieurs fréquences différentes sur le même brûleur le sont.

Toutes les fréquences détectées peuvent former **un canal collectif logiciel** :
la même chauffe est envoyée à chacune. Cela fonctionne avec un ou plusieurs
brûleurs, y compris des brûleurs nouvellement ajoutés. Les anciens canaux de
flottabilité compatibles sont regroupés ; les autres commandes ne sont pas
remplacées silencieusement. Les mappings explicites existants restent utilisables
lorsque les récepteurs ne sont pas directement adjacents, mais aucun nouveau
câblage indirect n'est deviné.

L'initialisation et le retour de chauffe vérifient **tous les brûleurs sélectionnés**.
Une réponse du transmetteur n'est jamais une preuve suffisante. Une absence ou
un désaccord arrête le test ; STOP envoie le secours à toutes les fréquences du
collectif. Les groupes sont liés au modèle de calibration : un changement de
membres ou de fréquences invalide la réutilisation de l'ancien modèle.

## Moteurs et propulseurs

Chaque propulseur est suivi dans le graphe réel de sources cinétiques Create.
La fréquence de chaque clutch, transmission et inverseur est reconnue par son RX
adjacent. Deux propulseurs qui partagent ces trois commandes appartiennent au
même groupe de commande, même s'ils sont éloignés.

Deux groupes indépendants restent les banques nominales gauche/droite. Avec plus
de deux groupes, leurs positions réelles dans le plot servent à former deux
banques logicielles selon X. Chaque banque peut envoyer son clutch, transmission
et inverseur sur plusieurs fréquences. Cette répartition n'est pas présentée
comme une connexion mécanique : la poussée, le lacet et le freinage collectifs
restent à mesurer avant tout trajet autonome. Un moteur alimentant plusieurs
propulseurs ne devient pas artificiellement plusieurs commandes indépendantes.

Le débrayage est transmis à **tous** les membres et leurs retours sont attendus
avant les changements de transmission/inverseur puis le réembrayage. Une seule
réponse correcte ne masque pas un autre RX absent, périmé ou incohérent. Les
fréquences ne peuvent pas se chevaucher entre rôles, banques ou brûleurs.

Un groupe unique, une chaîne incomplète ou une géométrie ne permettant pas deux
banques conserve le pilote vertical disponible sans fabriquer de direction. Si
une fréquence de brûleur est partagée avec une commande moteur connue, la
préparation refuse ce couplage : les deux commandes ne peuvent pas être isolées
par le logiciel.

## Limites et validation

Un rôle collectif peut réunir au plus 16 fréquences distinctes, sans modifier les
fréquences existantes du monde. Les couleurs d'items restent une partie de leur
identité. Les scans restent limités au plot parent chargé et aux sources connues
du bridge. Aucune recherche de moteur par simple proximité, écriture de physique,
ou réécriture de fréquence des blocs n'est ajoutée.

Tests : deux fréquences de brûleurs, couleurs distinctes, ajout d'un brûleur à une
configuration existante, chauffe fractionnaire collective, secours sur les deux
fréquences, propulseurs partageant une chaîne, quatre groupes moteurs répartis
en deux banques, vérification de tous les membres, refus partiels et chevauchement
de fréquence dans un membre secondaire. Tests avec plante simulée, pas une
validation en jeu du montage réel.
