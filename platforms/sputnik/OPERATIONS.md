# Sputnik 0.4.0 — poste de vol et journal

Le parcours est : choisir le TXT de l’architecture, configurer les commandes dans l’atelier unique, vérifier le montage, effectuer le passage physique OFF requis, activer le maintien, puis lancer les essais mesurés. Les routes restent conditionnées aux essais aller-retour du contrôleur. Une arrivée conserve un maintien ; l’atterrissage automatique n’est pas qualifié.

## Installation et migration

Importer **un seul graphe complet** : `mintcraft-quad-fpv.clipboard.txt` pour le quad expérimental, ou `mintcraft-balloon-autopilot.clipboard.txt`, `mintcraft-venator-autopilot.clipboard.txt`, `mintcraft-helicopter-autopilot.clipboard.txt`, `mintcraft-hybrid-autopilot.clipboard.txt`. Le quad standard reste disponible dans `mintcraft-quad-autopilot.clipboard.txt`.

Avant remplacement, exporter les groupes MCV1 et les routes MCR1. Retirer les anciens contrôleurs des fréquences réutilisées, importer le nouveau graphe, puis importer chaque groupe MCV1 dans l’atelier. Les quatre/six anciens formulaires sont remplacés par un seul sélecteur de groupe : changer de groupe conserve les paramètres du précédent. Les champs A/B conservent les descripteurs et les brouillons désactivés (préfixe `D,`). Seuls les groupes activés sont envoyés au contrôleur. Aucun modèle de vol actif ni sortie moteur n’est restauré automatiquement ; nouvelle vérification et OFF physique requis.

Les TXT dédiés comportent sept blocs. Le nom de compatibilité `mintcraft-autopilot.clipboard.txt` pointe maintenant vers l’atelier hybride compact. Chaque graphe possède un seul émetteur physique. Journal, montage et commandes ne transmettent aucun signal Link directement.

## Montage

Choisir le groupe, son type, son rôle, sa position déclarée, les voiles, le régime source et le nombre de moteurs identiques derrière cette commande. Choisir la paire de puissance et, selon le montage, les paires inverseur et clutch. Les paramètres experts complets restent disponibles. L’atelier normalise le sélecteur de type, signale les fréquences réutilisées et refuse les directions non unitaires.

La bibliothèque nommée conserve les groupes et, dans le graphe complet, les réglages de montage. Charger un montage remet les confirmations de zone, sens et reprise à vérifier. Les changements en vol restent des brouillons jusqu’au désarmement. La vue « brouillon » permet de vérifier la géométrie déclarée avant activation ; la vue « montage actif » provient du montage conservé par le contrôleur.

Les commandes partagées représentent une seule autorité. Le champ « moteurs identiques » conserve cette distinction ; il ne décrit pas exactement plusieurs hélices hétérogènes avec des écoulements différents. Un modèle agrégé local mesuré reste nécessaire dans ce cas. Ni le centre de masse réel, ni la coque, ni les voiles ne sont scannés automatiquement.

## Pilotage et navigation

Altitude, vitesse et cap de trajectoire restent séparés du montage. Les boutons nommés donnent accès au maintien, à l’altitude, au suivi vitesse/cap, aux essais, au retour au départ, à la reprise clavier, aux pauses et abandons. La révision acceptée est un ACK logiciel, jamais un acquittement radio ou mécanique.

Les six touches Link sont conservées. Les boutons +X/-X/+Y/-Y/+Z/-Z ajoutent des points depuis la position disponible dans le graphe, avec un pas réglable. Une position ouverte dans l’éditeur peut être la dernière donnée serveur synchronisée : vérifier le point avant de lancer la route. Les coordonnées manuelles, l’édition, la sélection et les routes nommées restent disponibles. « Suivre le point sélectionné » conserve la route éditée et demande uniquement ce point. Le cap du nez reste distinct du cap de trajectoire ; aucune autorité de lacet absente n’est créée.

L’arrêt horizontal, la reprise clavier, la pause de mission et la coupure mécanique sont distincts. Le contrôle horizontal arrêté conserve la demande verticale. Une coupure mécanique supprime la sustentation et impose le réarmement physique prévu par le contrôleur.

La carte affiche la route, la trace et les données déclarées. Elle n’annonce pas un terrain dégagé. Les zones interdites sont déclarées par l’opérateur. Le planificateur, ses marges, le freinage et le maintien final existants restent en service ; toutes les trajectoires et architectures ne sont pas qualifiées.

## Protection et adaptation

Le superviseur examine des observations nouvelles du contrôleur, au plus quatre analyses par seconde. Il distingue une oscillation persistante au maintien d’une commande clavier, d’un changement de consigne ou d’une phase de mission/calibration. Les commandes physiques restent exclusivement calculées et émises par le contrôleur.

Une oscillation peut réduire progressivement l’enveloppe d’inclinaison entre **50 % et 100 % du réglage opérateur**. L’altitude demandée ne change pas. Un essai aggravant les oscillations revient à l’enveloppe précédente et attend de nouvelles observations avant une autre adaptation. Une stabilité observée permet un retour progressif vers l’enveloppe nominale. Cette adaptation ne modifie pas les fréquences ou le montage, n’augmente pas le réglage opérateur et n’ajoute pas de plafond absolu de vitesse.

La demande `MCSUP1` est bornée et horodatée. Une donnée future, périmée ou hors plage ne remplace pas l’enveloppe déjà acceptée. Une oscillation sévère peut mettre le déplacement horizontal en pause. La protection reste mémorisée jusqu’au calme observé et à son acquittement, ou jusqu’à une désactivation explicite de l’opérateur. Elle ne commande jamais une coupure mécanique en réponse à une oscillation.

Le trim de charge et les récupérations des contrôleurs précédents sont conservés. L’enveloppe n’est pas un réglage automatique complet des PID ni une garantie de récupération. Les moteurs, délais, marges et efforts extérieurs peuvent rester hors du domaine stabilisable.

## Journal et export

Le contrôleur fournit un échantillon `MCF1` cohérent : tick, masse/inerties exposées, pose, vitesses disponibles, cible verticale, commandes réellement utilisées, mode, révision, enveloppe, saturation, effort estimé et niveaux transmis par groupe. Les états de groupe sont des **estimations internes** : tr/min pour une hélice, niveau de commande pour une réponse locale ou une gouverne. Ce ne sont pas des mesures d’arbre. Les empreintes des descripteurs vérifient la concordance avec le contexte actif déclaré ; ce ne sont pas des preuves d’appartenance au véhicule.

Le journal conserve au plus 1 200 observations et 393 216 octets de lignes, plus un instantané et un historique d’analyse bornés. Une longue interruption ne remplit pas les observations manquantes. Doublons, régressions et données périmées sont signalés. Un diagnostic stationnaire requiert notamment 20 observations successives fraîches, une faible vitesse et un objectif stable ; il ne confère pas une qualification globale.

Choisir « rapport court » pour les 120 dernières observations ou « historique complet ». Le premier défaut peut aussi figer automatiquement le contexte précédent et les observations disponibles après le défaut. Les exports sont paginés, sous la limite NBT de chaque champ. Les pages commencent par `MCLOG1;…` et comportent un numéro, un total et une somme de contrôle.

L’éditeur s’exécute aussi côté client. **Figer, sauvegarder/fermer, puis rouvrir** pour récupérer les champs exportés côté serveur. Choisir une page, sauvegarder/fermer et rouvrir si nécessaire pour obtenir cette page serveur ; conserver toutes les pages du même instantané. Les canaux Display Link `MC_FLIGHT_DIAG` et `MC_FLIGHT_EXPORT` exposent aussi le résultat serveur. Le journal ne dépend pas d’un système de fichiers CC ou d’un service HTTP. Un arrêt complet du calcul Lua interrompt sa collecte ; la fermeture de l’éditeur n’est pas un arrêt observable garanti.

## Analyse et rejeu

`python3 tools/replay-sputnik-flight.py page-1.txt page-2.txt --output analyse` vérifie les pages, leurs limites et leur intégrité, puis produit CSV et JSON. Aucun texte importé n’est exécuté. Les observations stationnaires, lacunes et défauts restent séparés d’une qualification de vol.

L’option `--controller chemin.lua --cosmonautics-jar chemin.jar --java-home chemin-jdk` permet de réévaluer les décisions dans le vrai LuaJ audité. Le contrôleur local explicitement choisi constitue le code exécuté. Les poses enregistrées restent imposées. L’état interne initial, les forces extérieures et certains objectifs de mission manquent : ce rejeu n’est ni bit pour bit garanti ni une prédiction de la trajectoire d’un autre réglage. Les intentions non reconstructibles sont signalées.

L’identification passive affiche un **candidat collectif en boucle fermée** lorsque l’excitation et les observations le permettent, avec un délai effectif et une corrélation. Elle ne sépare pas arbitrairement des moteurs commandés simultanément, ne prétend pas mesurer leur arbre et n’applique pas une courbe mécanique inventée. Les essais actifs existants partent d’un modèle renseigné ou d’un état connu ; leurs résultats partiels et candidats doivent être revérifiés.

## Distribution et limites

Le ZIP courant contient les graphes dédiés et les sources/tests. Le gros SDK agrégé de développement, le doublon de compatibilité hybride et quelques raccourcis complets anciens restent disponibles dans le dépôt et sont exclus de l’archive de vol ; les exclusions sont listées dans le manifeste. Chaque nœud respecte la limite de 60 000 octets UTF modifié.

Les sources Lua disponibles n’exposent pas de scan fiable de coque/voiles, de centre de masse réel, d’identité Sable garantie des périphériques, de terrain complet ou de contact d’atterrissage. Une reprise physique après arrêt du Lua exige un dispositif matériel approprié : l’expiration d’un Link peut produire zéro, donc le plein régime sur certaines transmissions. Les preuves publiées restent synthétiques et les essais Minecraft constituent une validation distincte.
