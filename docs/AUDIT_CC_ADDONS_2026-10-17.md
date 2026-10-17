# Audit CC:Tweaked et addons - 2026-10-17

## Perimetre et statut

Base examinee : MintCraftOS 0.18.7, commit
`de658bc87ff2dded1b9f57d023cea9b1f7c2c931`.

Audit des contrats addon, acquisition, controle, rendu, reseau, diagnostic,
audio et chemins de mise a jour. Relecture des protections de stockage et
d'execution ; ce document ne remplace pas un audit de securite hostile exhaustif.
Les constats ne sont PAS des corrections livrees. Aucun JAR, profil Minecraft,
monde ou actionneur n'a ete modifie ou execute. Pas de nouvelle release/push.

Methode : documentation officielle, API de publication GitHub/Modrinth filtree
Minecraft 1.21.1 + NeoForge, lecture du code local, inspection statique des JAR
avec ZIP et `javap`, tests Lua 5.2 et reproductions sur mocks. Les sources `main`
ou `master` ne prouvent jamais seules le comportement d'un ancien binaire.

## Versions verifiees

Le profil inspecte est `NeoForge 1.21.1 (1)` dans ModrinthApp. Cela ne prouve
pas la version effectivement chargee par un autre profil ou serveur distant.

| Composant | JAR dans ce profil | Publication 1.21.1/NeoForge trouvee | Conclusion |
| --- | --- | --- | --- |
| CC:Tweaked | 1.120.2 | 1.120.2, 2026-08-08, alpha | Deja a jour pour cette cible |
| CC:Sable | 1.3.4 | 1.3.4, 2026-05-13 | Deja a jour |
| Create: Avionics | 0.6.0 | 0.6.0, 2026-09-01, alpha sur Modrinth | Deja a jour ; tests de contrat indispensables |
| Create: Radars | 0.4.9.4 | 0.4.9.4, 2026-06-10 | Derniere publication publique trouvee pour cette cible |
| Radar EA fourni | 5.0-EA-3.0.0 dans Downloads | Binaire fourni, pas une release publique equivalente verifiee | Adaptateur distinct ; pas installe dans ce profil |
| CC:CBC | 1.1.1 | 1.1.1, 2026-05-21 | Deja a jour |
| Create Big Cannons | 5.11.7 | 5.11.7, 2026-06-22 | Deja a jour |
| Create | 6.0.10 | 6.0.10, 2026-04-21 | Deja a jour |
| Aeronautics bundle | 1.3.2 | 1.3.2, 2026-08-29 | Deja a jour |
| Sable moteur physique | 2.0.5 | 2.0.6, 2026-10-03 | Version plus recente disponible ; validation dans une copie de monde avant adoption |

CC:Tweaked 1.120.3 existe, mais la publication trouvee cible Minecraft 26.3,
pas 1.21.1. Ne pas remplacer un JAR en se basant uniquement sur le numero CC.
Sable 2.0.6 ne constitue pas une correction des erreurs Lua enumerees ci-dessous.

Sources : [releases CC](https://github.com/cc-tweaked/CC-Tweaked/releases),
[Avionics 0.6.0](https://modrinth.com/mod/create-avionics/version/0.6.0),
[Sable 2.0.6](https://modrinth.com/mod/sable/version/2.0.6%2Bmc1.21.1).
Verification des autres publications par les endpoints officiels
`https://api.modrinth.com/v2/project/<slug>/version`, filtres
`game_versions=["1.21.1"]`, `loaders=["neoforge"]` : `cc-sable`,
`create-radars`, `cc-cbc`, `create-big-cannons`, `create`, `create-aeronautics`.

## Constats prioritaires

P1 = corriger avant utilisation normale de la fonction concernee ; P2 = defaut
de fiabilite/diagnostic ou risque conditionnel. Aucun P0 demontre dans cette passe.

### A01 / P1 - Relachement CBC interprete comme un echec

Localisation : `system/services/combatd.lua:487`, `:525`.
Le code considere tout retour `false` de `fire(false)` comme un refus. Dans le
JAR CC:CBC 1.1.1, cette fonction retourne l'etat `FIRE_POWERED` apres la commande :
`false` est donc le resultat attendu d'un relachement reussi. Le code garde alors
`firing`, marque le canon incertain et refuse l'arret du service.

Reproduction Lua : mock `fire(value)` retournant `value`, contrairement au mock
actuel qui retourne nil. Apres un pulse : `fire release refused`,
`stop() -> false, combat output active/uncertain; wait for release`.
Correction : adaptateur CBC avec semantique explicite par methode ; comparer
l'etat retourne a l'etat demande, ne pas utiliser une regle generique false=refus.
Tester pulse, relachement deja off, exception, timeout et perte de connexion.
Le faux diagnostic est prouve ; un tir physiquement maintenu n'est pas demontre.

### A02 / P1 - Premiere observation radar consideree fraiche sans preuve

Localisation : `system/services/combatd.lua:167`, `:169`, `:176`, `:358`.
Un nouvel ID recoit `timestamp=now` des qu'un `scannedTime` numerique existe,
meme si cette date est ancienne. `freshnessKnown=true` signifie presence d'un
nombre, pas validation de son age. Une mesure conservee par le radar peut ainsi
etre utilisable pendant cinq secondes au demarrage ou apres eviction du cache.

Reproduction : nouveau contact avec `scannedTime=-999999` -> `stale=false`,
`freshnessKnown=true`, et `solution()` produit des angles. Le point important est
l'absence de relation d'age, pas la valeur negative utilisee dans ce test.
Correction : distinguer date de reception, tick de scan, horloge source et age
verifie. Sans horloge source comparable, garder la premiere observation non
commandable jusqu'a constater une progression de scan dans une fenetre bornee.
Ne pas confondre `getGameTime()` du mod avec l'uptime du PC ou l'heure solaire.

### A03 / P2 - Mauvaise signature de pression CC:Sable

Localisation : `system/services/sabled.lua:96`.
Appel actuel `aero.getAirPressure(position)` ; le JAR 1.3.4 et le source tague
exigent `getAirPressure(double x, double y, double z)`. La pression devient
indisponible et le service passe en etat degrade sur un sublevel avec pose.
Reproduction : stub exigeant trois nombres -> `three numeric coordinates required`.
Correction : valider le vecteur, passer ses trois composantes et tester les axes.
[Contrat tague](https://github.com/TechTastic/CC-Sable/blob/v1.3.4/common/src/main/java/io/github/techtastic/cc_sable/apis/AerodynamicsAPI.java).

### A04 / P1 conditionnel - Visee mobile limitee au lacet

Localisation : `system/services/combatd.lua:365`, `:371`.
Pour un profil `headingFrame=body`, le code soustrait seulement le cap au bearing.
Le pitch balistique reste calcule dans le repere monde. Cela ne constitue pas
une transformation complete monde -> monture lorsque le vaisseau est incline.
Constat mathematique dans le code ; comportement exact des montures mobiles a
confirmer en jeu. Avant cela, refuser explicitement les solutions hors domaine
calibre, plutot que presenter ces angles comme une solution mobile valide.
Evolution : quaternion de monture, pivot reel et gravite exprimes dans un meme
repere ; tests inclinaison/roulis et limites avant tout essai en jeu.

### A05 / P2 - Readiness Avionics trop permissive

Localisation : `system/libraries/addon.lua:40`, `system/services/avionicsd.lua:41`.
`addon.read` ignore les methodes absentes et un capteur est sain si n'importe
quelle valeur est presente. En retirant seulement `getAngles` d'un gimbal,
le service et le capteur restent `ok=true`, mais la mesure pitch est invalide.
Le controle de vol refuse ensuite les valeurs absentes : ce n'est pas une preuve
de pilotage sur nil, mais le diagnostic affiche une fausse compatibilite.
Correction : champs requis/optionnels, validation de type et erreur de contrat
par mesure. Un module optionnel absent ne doit pas invalider les autres mesures.

### A06 / P2 - Auto-setup Radar depend d'un bridge non standard

Localisation : `system/services/combatd.lua:93`, `:277` et `docs/RADAR_API_BRIDGE.md`.
Les JAR originaux 0.4.9.4 et 5.0 EA inspectes ne contiennent pas `getScanGeometry`.
Leur bearing declare aussi `getPosition(StationaryRadarBlockEntity)`, mauvais
receiver pour un bearing. Le source public master a deja un receiver different :
il ne faut donc pas le confondre avec le binaire installe.
Le bridge local est documente et optionnel, mais Auto setup ne peut pas etre
annonce comme une capacite native des deux versions. Les choix `4.x`/`5.0-EA`
ne selectionnent pas actuellement deux adaptateurs de lecture dans combatd.
Correction : afficher profil detecte, preuve de capacites, origine du bridge et
limites ; adaptateurs stock 4.x, EA et bridge separes. Chercher une integration
amont documentee avant de generaliser la modification de JAR. Verifier les
conditions de distribution du mod pour tout bridge distribue.

### A07 / P2 - Repere du centre de masse non suffisamment etabli

Localisation : `system/services/sabled.lua:183`.
Le centre de masse est etiquete `body`, mais l'API renvoie directement celui du
MassTracker ; un signalement amont mentionne des coordonnees shipyard. Ne pas
traiter cette etiquette comme une conversion faite. Conserver la valeur brute
et le repere non valide, puis verifier avec pivot decale et rotation du sublevel.
[Signalement amont](https://github.com/TechTastic/CC-Sable/issues/13).

### A08 / P2 - Fraicheur par mesure perdue dans les snapshots

Localisation : `system/services/sabled.lua:74`, `:183` et
`system/services/avionicsd.lua:54`, `:65`.
Les diagnostics lents Sable sont conserves une seconde mais republies avec la
date du snapshot rapide. Avionics calcule une date par entree, puis utilise la
date globale pour toutes les mesures normalisees. Impossible de distinguer
exactement acquisition, reutilisation du cache et derniere valeur valide.
Correction : `observedAt`, `receivedAt`, `validUntil` et source pour chaque champ ;
garder l'ancien timestamp lors d'une copie. L'horodatage ne remplace pas la
validite de type ni l'identite du capteur selectionne.

### A09 / P2 - Fusion multi-radar des flags depend de l'ordre de retour

Localisation : `system/services/combatd.lua:168`, `:184`.
La position ne change que si le scan est plus recent, mais `friendly` et
`synthetic` sont remplaces meme par un scan plus ancien venant d'un autre radar.
Un etat de classification peut donc ne pas correspondre a la mesure retenue.
Correction : provenance/date de classification par source, regle conservatrice
pour le controle et test de deux radars avec dates opposees et flags contradictoires.

### A10 / P2 - Budget d'acquisition non dimensionne pour un grand reseau

Localisation : `system/libraries/addon.lua:38`, `:93`, `:115` et
`system/services/combatd.lua:84`.
Une branche est creee pour chaque peripherique, puis chaque methode ; toutes
partent ensemble. Un scan stock de 40 bearings demande jusqu'a 240 lectures par
cycle, soit 1 200 appels/s a 5 Hz, avant canons et autres services. Ce compte
est statique, pas une mesure de debit en jeu. Les deadlines courtes et la limite
globale peuvent produire du degrade sous charge, sans prouver un mod absent.
Correction : inventaire commun, budget de lectures par tick, concurrence bornee,
priorites vol > commandes > contacts > diagnostics, detection des cycles depasses.
Ne pas simplement passer toutes les acquisitions a 20 Hz.

### A11 / P2 - Travail crypto entrant dans la boucle centrale

Localisation : `system/services/radarnetd.lua:105`, `:135`, `:281`.
HMAC et deserialisation sont executes directement dans le callback event bus,
avant la limitation de frequence des stations connues. La limite de taille
64 KiB protege la taille unitaire, pas le cout d'un flot de messages invalides.
Risque de latence, pas de contournement HMAC demontre.
Correction : file d'entree bornee, budget global, worker de verification,
priorite aux stations appairees et statistiques de rejets. Ne jamais accepter
un paquet non authentifie pour accelerer la reception.

### A12 / P2 - Telechargement Update contourne le lecteur HTTP borne

Localisation : `system/services/updated.lua:91`, `:106`.
Browser utilise le client HTTP borne, mais Update garde son propre `readAll()`
sans plafond applicatif. Un depot configure ou une reponse trop volumineuse peut
consommer beaucoup de memoire ; les limites serveur CC ne constituent pas une
limite adaptee au fichier attendu. Correction : chemin HTTP commun avec plafonds
distincts VERSION / metadonnees commit / installateur et fermeture sur erreur.
Le pin par SHA et les transactions existantes doivent etre conserves.

### A13 / P2 - Echec de cible d'affichage encore fatal au compositeur

Localisation : `system/gui/compositor.lua:13`, `:47`.
Un `getSize()` ou `blit()` sur un monitor devenu indisponible est propage jusqu'au
kernel, au lieu d'invalider la cible puis revenir au terminal natif. Le service
gere les evenements de detach, mais pas toutes les courses avec un flush.
Risque identifie dans le chemin d'erreur, non reproduit sur un serveur Minecraft.
Correction : distinguer faute d'app et faute de sortie ; rebind au natif,
invalidation et notification, sans rejouer une commande materielle.

### A14 / P2 - Resultat audio confondu avec absence d'exception

Localisation : `system/drivers/speaker.lua:150`, `:163`.
`playNote`/`playSound` retournent true si pcall reussit, meme si le speaker refuse
la lecture avec false. Le statut peut donc annoncer un son non joue.
Correction : respecter le resultat API et appliquer une politique de priorite
alarme/notification/audio utilisateur. Le DFPWM par blocs 16 KiB et la reprise
sur `speaker_audio_empty` constituent deja une bonne base.

## Optimisations proposees, sans promesse de gain non mesure

1. **Snapshots specialises** : `flightTelemetry(sensorIds)` au lieu de copier
   tout Avionics et Sable a chaque `validate()`, `status()` et tick de vol.
   Cacher le rang du mixer selon revision de configuration, pas selon redraw.
2. **Statuts O(1)** : radarnet.status() ne doit pas appeler un snapshot copiant
   tous les contacts/historiques. Conserver compteurs et derniere erreur.
3. **Rendu a la demande** : Combat se reveille a 20 Hz mais la geometrie depend
   d'un snapshot 5 Hz. Invalider selon revision/vue ; rafraichir les petits
   compteurs d'age separement. Pas d'information radar nouvelle creee par redraw.
4. **Sous-pixels** : garder le canevas 2x3 existant ; cacher fond, cercles,
   projection et palette selon leurs entrees. Ne reconstruire que les contacts
   et faisceaux modifies. L'horizon fait encore une boucle sur tous ses pixels.
5. **Compositeur** : il compare deja les lignes et envoie `term.blit` seulement
   si elles changent. Ajouter des regions sales pour eviter aussi la recomposition
   CPU de tout le bureau ; reutiliser les buffers au lieu de recreer nextFrame.
6. **Cadence adaptative** : cible graphique 20 Hz, mesure du debit effectif,
   reduction 10/5 Hz sous charge. La collecte de vol reste prioritaire. Les appels
   mainThread suspendent jusqu'au tick serveur ; leur regroupement independant
   existe deja et doit etre conserve, sans ecritures concurrentes sur un endpoint.
7. **Rendu 3D mobile** : representer une direction et un volume orientes par
   quaternion, pas seulement un cap et un cone horizontal. La vue actuelle est
   orthographique et schematique, pas un moteur Minecraft.
8. **Audio/config** : cacher audio.cfg et invalider a l'enregistrement ; ne pas
   relire le disque a chaque status/notification. File audio a capacite bornee.

## Capacites disponibles a integrer utilement

- **CC redstone_relay** : backend nom du relais + cote pour depasser les six
  sorties du PC sans ajouter un autre mod. Garder chaque endpoint calibre,
  neutre/secours explicites, confirmation et traitement du detach.
  [API officielle](https://tweaked.cc/peripheral/redstone_relay.html).
- **Avionics** : le service reconnait sept familles, pas tout le catalogue.
  Prioriser `velocity_sensor`, `gyroscopic_propeller_bearing`, `portable_engine`,
  `steering_wheel`, `linked_typewriter`, puis cinematique Create. Decouverte,
  lecture et controle doivent etre trois capacites distinctes.
- **Evenements Avionics 0.6.0** : les evenements de gantry documentes permettent
  une future supervision de machines moins dependante du polling. Ce n'est pas
  une API permettant d'accelerer arbitrairement les scans radar.
- **Monitor** : preference persistante par nom, choix auto/natif/monitor,
  echelle par cible et test de retour natif au detach. `setTextScale` accepte
  0.5..5 par pas de 0.5 ; le sous-pixel ne cree pas de police haute resolution.
  [API monitor](https://tweaked.cc/peripheral/monitor.html).

Sources de conception : [Avionics](https://solastrius.github.io/CreateAvionics/),
[appels suspendus et batching](https://solastrius.github.io/CreateAvionics/guide/mainthread.html),
[term/blit](https://tweaked.cc/module/term.html),
[speaker](https://tweaked.cc/peripheral/speaker.html).

## Plan d'execution recommande

### Lot 1 - Contrats et garde-fous

A01, A02, A03, A05, A09 et A14 ; garde de domaine pour A04 ; snapshots avec
validite/date par mesure. Creer des fixtures correspondant aux JAR exacts,
retours false/nil compris. Pas de hausse globale de frequence ni nouveau controle.

### Lot 2 - Architecture et performance

Inventaire partage, files de lecture/commande bornees, snapshots specialises,
cache de calcul et statuts constants. Instrumenter duree acquisition/calcul/draw,
appels par methode, cycles rates, timeout, octets Rednet, lignes/cellules blittees,
heap Lua et taille des files. Publier p50/p95 et debit observe, pas un faux CPU %.

### Lot 3 - Setup addon et UX

Assistant par capacites, profils stock/EA/bridge clairement visibles,
selection de capteurs et relais, echelles par monitor, commandes desactivees avec
raison actionnable. Import/export de configurations, sans exporter les secrets.
Orientation 3D et ballistique mobile seulement apres tests de reperes.

### Validation de chaque lot

- CC:Tweaked 1.120.2 en jeu, puis changement de Sable dans une copie de monde.
- Absence/hotplug, lecteur suspendu, TPS reduits, saturation, paquet invalide,
  monitor detache pendant flush, changement de scale, pocket et monitor 4x3.
- 1/10/40 radars, 0/32/128 contacts, 20 points de trajectoire, plusieurs stations.
- Scan initial ancien, progression/recul du tick, doublons, flags contradictoires.
- CBC : confirmation par cible/canon, false attendu au stop, timeout non rejoue.
- Vol : simulation seulement avant essai progressif calibre ; pas de rearmement
  automatique, pas de garantie logicielle en cas de gel/perte d'alimentation.

## Verifications realisees pendant cet audit

58 suites Lua rapides passees, 5 tests Node passes. Le test PBKDF2 de production
long avait passe pour la release ; il n'a pas ete relance dans cette passe.
Reproductions ponctuelles confirmees : A01, A02, A03, A05, A09 et A14, sans changer les
tests existants. Cela montre pourquoi des tests verts ne prouvent pas la
conformite aux vrais contrats. Pas de test de vol/tir ou de charge en jeu ici.

Empreintes SHA-256 des binaires inspectes :

```text
CC:CBC 1.1.1
0afc7fe10d31c87c0737ad1c3e443c87d3b57aab93a9628fdf51c3ee4053b535
Radar 0.4.9.4
4554359fee389b1c255b4cef23ac41e978b2a371cec9e952185f4ec0a90ee930
Radar 5.0-EA-3.0.0
773e0d3bf396d071753de76313dd05ac76be4be0e350255db89e15dfdd7c1b9a
```

La compatibilite Lua ne garantit pas l'absence de bugs dans le moteur physique,
le renderer Minecraft, le reseau serveur ou les dependances Java des mods.
