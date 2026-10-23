# Ascendancy A.3 — observations des essais moteur, 0.18.83

Pour revenir depuis 0.18.87 ou plus récent, utiliser le
[retour compatible avec le format 2](COMPACT-SOURCE-0.18.87.md) ;
les commandes d'installateur ancien ci-dessous concernent le format précédent.

Cet incrément **partiel du lot A** relie les dérivées six axes de A.2 aux essais
moteur déjà autorisés par `flightd`. Il ne change ni les impulsions, ni leur durée,
ni l'allocateur différentiel, ni le maintien vertical. Il ne certifie aucun nouvel
axe et ne livre pas la calibration universelle ou le pilotage multirotor.

## Utilisation et données

Lancer la préparation automatique existante, après confirmation d'une zone libre.
Le collecteur accompagne les 60 modes moteur, ou les quatre recontrôles d'un
modèle réutilisable. Aucun bouton, périphérique ou signal supplémentaire n'est
nécessaire. Les consignes altitude/vitesse/cap existantes restent identiques.

`flightd.status().motorExperiments` expose les résultats de la session ;
**Save report** les conserve dans le rapport de calibration. Ces données sont
des diagnostics, pas une autorisation de commande. Les anciens profils restent
lisibles. Aucun recalibrage exploratoire n'est ajouté pendant une mission ou
l'adaptation de masse.

Chaque groupe contient :

- Banque gauche/droite, niveau de transmission et inverseur réellement essayés.
- Identité du véhicule, horloge locale de session, intervalle des observations.
- Quaternion de référence au neutre et instant de cette référence.
- Accélérations avant/droite/verticale en blocs/s² et rotations tangage/lacet/roulis
  en degrés/s², dans **le même repère corps fixé au neutre**.
- Réponse moyenne moins la réponse au neutre, dispersion observée, nombres
  d'échantillons et motif précis si les données sont insuffisantes.
- Vitesses de fonctionnement et au neutre, dans ce même repère, avec les unités
  et les instants moyens distincts des vitesses et accélérations.

Les rotations utilisent les quaternions Sable acceptés par A.2 ; elles ne
supposent pas que les vitesses angulaires natives sont en repère monde et ne
reprennent pas silencieusement les signes Euler d'Avionics.

## Conditions et limites

Les capteurs doivent être frais, du même véhicule et de la même session. Les
unités et intervalles sont vérifiés. Seuls les intervalles de dérivation
**entièrement postérieurs** aux confirmations moteur et brûleur sont admis.
Un changement de chauffe réinitialise le neutre et rend l'essai moteur concerné
inutilisable pour l'attribution des effets. Le neutre exige des vitesses de
translation et de rotation faibles. Il faut au moins quatre observations au
neutre et trois observations après confirmation pour qualifier les données.

Un retour RX lent peut laisser trop peu d'intervalles après confirmation avant
la fin d'une impulsion existante. L'impulsion n'est pas prolongée pour remplir
le collecteur : le résultat reste insuffisant. Une perturbation externe reste
possible ; la soustraction au neutre **n'identifie pas à elle seule une matrice
de forces ni un modèle dynamique complet**. Les vitesses de fonctionnement sont
conservées pour permettre une future analyse de cette dépendance.

La dispersion calculée est la racine de la somme des variances au neutre et
pendant l'essai. Ce n'est pas un intervalle de confiance : les dérivées de poses
peuvent partager des échantillons. Le masque de réponse observée utilise cette
dispersion et un seuil numérique, sans certifier d'autorité indépendante.
`notControlCertificate=true` reste explicite dans chaque groupe.

## Budgets et réutilisation

Le collecteur conserve des statistiques en ligne pour un neutre et une impulsion,
sans historique de poses additionnel, puis au plus quatre résultats : deux banques
fois deux sens d'inverseur. Il préfère un résultat utilisable à un résultat trop
court, puis la réponse longitudinale la plus forte. Le niveau exact est conservé ;
ce résumé n'est pas présenté comme une caractérisation des 60 modes six axes.
Les lignes moteur historiques restent dans `motorTests` une seule fois.

Lors d'une réutilisation, les observations d'origine restent dans
`motorExperiments` avec `historical=true` ; les quatre essais frais restent dans
`freshMotorExperiments`. Un recontrôle ne renouvelle pas artificiellement les
horodatages d'origine. Si les réponses ont changé, la calibration existante
repart sur ses 60 modes et le collecteur repart vide. Aucun modèle six axes
sauvegardé n'est consommé comme preuve par le contrôleur.

Le plafond de rapport de 65 536 octets, le contrôle d'espace disponible et les
écritures transactionnelles restent actifs. Le collecteur ne fait aucune lecture
de périphérique et aucune écriture d'actionneur. Le propriétaire, les permissions,
STOP/F10, la reprise manuelle et l'arrêt à fermeture restent ceux de `flightd`.

## Compatibilité et retour

Aucun changement de schéma global de calibration, de configuration utilisateur ou
de JAR Vehicle Bridge 0.2.3. Les nouveaux champs sont facultatifs. Un ancien code
les ignore ; aucune suppression de rapport n'est nécessaire.

Après STOP explicite, revenir au code 0.18.82 :

```lua
wget run https://raw.githubusercontent.com/commandant-x/MintCraftOS/ba9b18782b9d6e3a48334dc9ff66cbeab5298431/install.lua
```

Les paramètres et fichiers utilisateur sont préservés. Aucun historique permanent
supplémentaire n'est activé ; la récupération des écritures interrompues demeure.

## Qualification

Les tests dédiés vérifient les intervalles post-RX, le changement de chauffe,
la soustraction au neutre, la dispersion, les horodatages, l'isolation du véhicule,
les copies de données et les bornes. Le simulateur de service vérifie l'intégration
aux vrais chemins de commande des 60 essais, l'enregistrement puis les quatre
recontrôles, ainsi que STOP, défauts et adaptation de masse.

Les résultats de taille et des suites complètes figurent dans le statut du projet.
**Aucun essai Minecraft effectué** : qualifier en zone libre sur installation de
test, examiner les groupes utilisables et les motifs d'insuffisance, puis vérifier
F10, le maintien vertical et les retours de tous les récepteurs.
