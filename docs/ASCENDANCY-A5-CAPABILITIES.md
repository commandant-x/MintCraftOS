# Ascendancy A.5 — vue native État, 0.18.85

Incrément **partiel du lot A**, pas une annonce d'autonomie complète.

Dans Navigation > Autopilot, cliquer **État** dans la barre supérieure du cockpit.
La vue native en lecture seule rassemble :

- État du service et véhicule détecté.
- Maintien vertical actif, guidage différentiel disponible ou motif de refus.
- Altitude, vitesse, cap et consignes ; chauffe demandée et adaptation de masse.
- État de calibration, tests observés dans la session et reprise manuelle.
- Motif actuel du sweep, notamment les diagnostics A.4.
- Dérivées six axes fraîches, dans leurs unités et leur repère vérifiés.
- Quatre résumés d'observations moteur au maximum et leurs limites A.3.
- Enveloppe empirique de freinage, suspension horizontale et progression du trajet.
- Limites actuelles d'ATLAS et de l'atterrissage automatique.

**Pilotage** revient aux consignes, sans les appliquer. **Initialiser** ouvre la
préparation existante avec confirmation de zone libre ; la consultation de l'état
ne lance aucun essai. **STOP/F10** reste accessible, même dans cette vue et pendant
une saisie invalide ailleurs. Le brouillon des consignes n'est pas envoyé en
ouvrant la vue. Aucun nouvel onglet global n'est ajouté.

L'état actif exige un service à jour ; les valeurs de télémétrie périmées ne sont
pas affichées comme mesures courantes. Les observations six axes exigent aussi
une pose monde fraîche du même véhicule, leurs unités attendues, le repère corps
à la dernière pose et une date de validité non expirée. Mesurer une accélération
latérale ne certifie pas un actionneur latéral. Les tests anciens dans la session
et l'enveloppe de référence ne réarment pas le véhicule et ne rétablissent pas une
capacité invalidée par les protections.

La vue annonce explicitement les axes automatiques non qualifiés et l'absence
actuelle de terrain/évitement garanti ou d'atterrissage qualifié. Elle n'altère
ni le contrôleur manuel existant ni le maintien vertical déjà utilisable.
Les résumés moteur sont des données d'essai, jamais un certificat de commande.

## Budgets et sécurité

Uniquement des caches déjà obtenus par Navigation : aucune lecture de périphérique
ni écriture physique depuis le dessin. Au plus quatre résumés moteur et moins de
trente lignes ; les messages longs sont tronqués à 384 caractères par ligne.
Le formulaire natif gère défilement et petites fenêtres. Le propriétaire, les
permissions, les retours RX, STOP et l'arrêt à fermeture restent ceux de `flightd`.

Aucune migration, nouvelle persistance ou modification de JAR Vehicle Bridge.
La récupération transactionnelle et les données personnelles restent inchangées.
Après STOP explicite, revenir à 0.18.84 :

```lua
wget run https://raw.githubusercontent.com/commandant-x/MintCraftOS/18ca56c506d1cdc08be6487d72b3d83d2e00d8bc/install.lua
```

## Validation

Tests des états vertical seul/différentiel, mesures périmées, UUID différent,
unités incorrectes, adaptation de masse, suspension et bornes. Test du vrai chemin
graphique : la consultation ne commande rien, STOP fonctionne et quatre tailles
156×180 à 958×491 sont couvertes. Le rendu 600×400 a également été inspecté.
Résultats complets et taille installée dans le statut du projet.

Aucun essai Minecraft effectué. Dans le jeu, vérifier la lisibilité sur le Computer,
la transition vers l'état périmé lors d'une perte de capteur, puis F10 sur une
installation de test. L'ensemble du lot A reste en cours.
