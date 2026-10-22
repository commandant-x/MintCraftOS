# Ascendancy A.4 — diagnostic de progression du sweep, 0.18.84

Incrément **partiel du lot A**. Le sweep conserve sa qualification physique :
huit observations fraîches, acquittées et contiguës, vitesse verticale absolue
au plus 0,1 m/s et dispersion de hauteur au plus 0,5 m. Aucun délai maximal,
niveau forcé, limite de vitesse ou de déplacement par défaut n'est ajouté.
Les limites optionnelles de l'opérateur restent actives.

## Utilisation

Dans Navigation > préparation automatique / Calibration, lire le motif du sweep
sous l'état courant. L'écran existant affiche maintenant notamment :

- Attente du retour de **tous** les récepteurs du groupe de brûleurs.
- Collecte de huit observations contiguës, ou reprise après un trou de mesure.
- Montée/descente à vitesse constante : ce n'est pas une altitude stable.
- Changements répétés du sens vertical au-delà du seuil : oscillation observée.
- Vitesse ou dispersion de hauteur encore trop grande.
- Absence de progrès clair après huit fenêtres de mesures distinctes.
- Niveau 15 demandé : chauffe maximale demandée, autorité de portance non établie.

Ce dernier message n'affirme pas qu'un bloc est en panne ni que le plafond de
vol physique est connu. Les mesures de vitesse et de hauteur restent nécessaires.
Le collecteur n'invente pas de portance à partir du niveau redstone.

Le diagnostic explique l'attente ; il ne termine pas une calibration impossible
par une fausse réussite. **STOP/F10** ou la commande manuelle permettent toujours
d'abandonner et d'appliquer le secours configuré. Si le vaisseau atteint plus
tard la vraie stabilité, le sweep peut continuer normalement, sans redémarrage.
Il ne lance aucune recherche supplémentaire de chauffe pendant une mission.

## Mesure de progrès

Une fenêtre utilise les huit dernières observations admises par le sweep ;
l'intervalle, la contiguïté et les critères existants restent inchangés. Le score
diagnostic est le maximum de la vitesse absolue normalisée par 0,1 m/s et de la
dispersion de hauteur normalisée par 0,5 m. Il n'est ni un PID ni une preuve de
contrôlabilité. Deux changements de sens au-dessus de ±0,1 m/s dans une fenêtre
signalent une oscillation observée.

La comparaison conserve au plus huit fenêtres **sans échantillon partagé**.
Après huit fenêtres, une réduction inférieure à 10 % du score initial (avec une
marge numérique minimale de 0,05) est signalée comme absence de progrès clair.
Il s'agit d'un seuil de diagnostic, pas d'un critère de réussite, d'un arrêt ou
d'une limite de durée. Les redessins, timestamps dupliqués et retours RX manquants
ne remplissent pas ce compteur. Un trou dans les observations efface les fenêtres
de comparaison. Un nouveau niveau de chauffe repart avec un diagnostic distinct.

`flightd.status().sweep.diagnostic` et `levels[heat].progress` exposent ces
résumés. `clock=sweep_elapsed` indique que `observedAt` est le temps écoulé depuis
le début du sweep, et non une mesure réutilisable après redémarrage. Les valeurs
arithmétiques non finies restent indisponibles. Aucune acquisition ni commande
physique dans le module ou le dessin ; `flightd` demeure l'unique autorité.

## Données et retour

Aucune migration ni modification de configuration, de modèle qualifié ou du JAR
Vehicle Bridge 0.2.3. Les champs diagnostics sont facultatifs et les lecteurs
anciens les ignorent. Aucun historique de télémétrie continu n'est conservé.
Les transactions de mise à jour et les fichiers personnels sont préservés.

Après STOP explicite, retour à 0.18.83 :

```lua
wget run https://raw.githubusercontent.com/commandant-x/MintCraftOS/6e3ea5001a24ba56eba986fb7ad706d7bfac03f7/install.lua
```

## Tests

Les tests dédiés observent une montée prolongée pendant 10 001 échantillons sans
fin de délai ni faux succès ; puis une stabilité réelle permet d'avancer. Ils
couvrent aussi oscillation, amélioration, retour RX absent, gaps, copies et mémoire
bornée. Les tests existants du service vérifient les sorties effectives, STOP,
l'initialisation, le secours, le maintien, l'adaptation de masse et les moteurs.
Les tailles et résultats complets sont enregistrés dans le statut du projet.

Aucun essai Minecraft effectué. En zone d'essai libre, vérifier que le motif
change avec les observations, puis que F10 applique le secours à tous les groupes.
Ce diagnostic n'ajoute ni calibration universelle, ni évitement, ni atterrissage.
