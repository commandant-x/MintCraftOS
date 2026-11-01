# Sputnik 0.4.2 — mondes construits et TXT

[Télécharger les six mondes et leurs TXT](mintcraft-sputnik-fleet-0.4.2.zip)

Six constructions ont été essayées sur un vrai serveur Minecraft avec le pack VENATOR fourni. Chaque dossier Mondes/ est une sauvegarde indépendante, contenant le véhicule et son Sputnik configuré. Aucun mod tiers ni monde personnel n'est redistribué.

1. Installer le même pack VENATOR 1.0.0 (Minecraft 1.21.1, NeoForge 21.1.264).
2. Copier le dossier du monde choisi depuis Mondes/ dans le dossier saves de cette instance. Garder tous ses fichiers, notamment sublevels/ : les seuls fichiers region/ ne suffisent pas à conserver un véhicule Sable.
3. Ouvrir le monde. Le mode est créatif, les commandes sont disponibles et le point d'apparition est près du véhicule. positions.json contient ses coordonnées.
4. Les sources créatives ont été mises à 0 RPM, les leviers à OFF et le véhicule est verrouillé par le Physics Staff. Les émetteurs de test sont retirés. Restaurer les sources mesurées à 256 RPM, garder le verrou pendant la vérification mécanique puis appliquer le passage physique OFF/ON avant tout nouvel essai. Les brûleurs restent dépendants de leur configuration spécifique.

Le TXT de chaque véhicule est dans TXT/. Il s'importe dans le fond vide de l'éditeur Sputnik, pas dans un champ Lua. Les fréquences sont communes entre mondes ; ne pas réunir les véhicules sans les réattribuer côté matériel et côté graphe. Les graphes sont spécifiques aux constructions fournies.

Résultats stricts : tricoptère corrigé 9/9 ; quad standard 5/9 ; quad propulsé 7/9 ; hexacoptère 6/9 ; octocoptère 7/9. Le ballon vertical réussit maintien, montée, descente et choc ; ses cinq commandes horizontales vérifient seulement le maintien, car il n'a pas de propulsion horizontale. Les échecs restent documentés. Aucun modèle n'est globalement qualifié ; joueur embarqué, changement de charge et atterrissage ne sont pas validés.

Hélicoptère complet, avion et V22 avec transition ne sont pas livrés dans cette campagne. Les simples graphes de configuration existants ne constituent pas leurs essais de vol.

Code, CSV, courbes et sources : https://github.com/commandant-x/MintCraftOS/tree/codex/sputnik-native-fleet/platforms/sputnik/reports/native-fleet-0.4.2

Les copies d'ouverture ont été rechargées dans Minecraft pour vérifier sept nœuds, 34 connexions, les sources à zéro et le verrou. Seuls le nom du monde, l'activation des commandes et les métadonnées du mod d'instrumentation ont ensuite été adaptés pour la distribution. Les mesures de vol brutes restent séparées.
