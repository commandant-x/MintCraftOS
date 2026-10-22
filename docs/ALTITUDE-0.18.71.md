# Altitude 0.18.71 — stabilité mesurée et séquence automatique

## Utilisation

Après mise à jour et redémarrage, ouvrir Navigation → Altitude. Les options
« Automatic initialization + rescue signal test » et « Enter vertical hold if
measured model qualifies » sont activées par défaut. Choisir Start sequence,
lire le récapitulatif, puis CONFIRM. Une confirmation autorise tout cet essai de
mouvement ; on ne répète plus manuellement Initialize, Test rescue, puis Sweep.

La séquence commande le premier niveau de chauffe et attend un retour frais de
**chaque brûleur choisi**, puis commande le signal de secours configuré et attend
à nouveau chaque retour. Elle passe ensuite automatiquement aux mesures. Un
acquittement du transmetteur ne remplace jamais le retour des brûleurs. Au signal
nul, l'absence de référence Aeronautics n'est acceptable qu'après initialisation
confirmée du même groupe, avec le signal reçu et le gaz effectivement nuls.

Pour chaque chauffe (7 à 15 par défaut), il faut huit échantillons frais,
consécutifs et acquittés avec **|vitesse verticale| ≤ 0,1 m/s**, une étendue de
hauteur ≤ 0,5 m et sans trou de télémétrie. L'altitude enregistrée est leur
moyenne. Un passage fugitif par zéro ou une montée à vitesse constante ne valide
pas le niveau. Il n'y a plus de durée maximale par niveau, de durée maximale du
sweep, ni d'abandon au bout d'un nombre d'échantillons. Les anciens paramètres
dwell/timeout ne fixent plus de limite. La RAM reste bornée : 24 premiers et
16 derniers échantillons par niveau, plus les agrégats et la fenêtre courante.

Si le ballon ne trouve jamais d'équilibre à une chauffe, la séquence attend
jusqu'à STOP/F10 ou une perte réelle des conditions nécessaires. Elle n'invente
pas de hauteur stabilisée. Les protections de télémétrie, identité, inclinaison,
permissions, propriétaire, erreurs de sortie et reprise manuelle restent actives.
Le délai existant de perte de retour d'un brûleur est une détection de panne de
commande, pas une durée maximale pour stabiliser le vol. Les limites facultatives
de vitesse/déplacement restent désactivées par défaut.

## Passage au pilote vertical

Une fois toutes les hauteurs stabilisées, le programme vérifie que la table est
croissante et distincte, puis identifie la réponse altitude/vitesse/chauffe. Une
validation indépendante doit confirmer le rappel, l'amortissement et la cohérence
entre cette dynamique et les hauteurs mesurées. Une table incomplète, un véhicule
bloqué au sol, une réponse bruyante ou non identifiable conservent les mesures
mais ne déclenchent pas le maintien automatique.

Si le modèle est qualifié et l'option activée, le retour au secours est confirmé,
puis un maintien **vertical uniquement**, limité à cette session, prend la
hauteur du dernier niveau comme consigne. Target altitude → saisir les mètres →
Set altitude permet de changer la consigne dans l'intervalle réellement mesuré.
La chauffe de base est interpolée dans la table ; la correction utilise le rappel
et l'amortissement mesurés. Les chauffes fractionnaires alternent les entiers
voisins uniquement après de nouveaux retours des récepteurs. La perte de retour
ne peut donc pas être masquée par une succession de nouvelles commandes.

Ce passage n'enregistre aucune fausse validation physique du sens, de la reprise
manuelle ou du comportement de secours. Il ne qualifie pas le vol horizontal et
ne démarre aucune route. La précision au mètre dépend du montage et doit être
vérifiée dans Minecraft. Une ancienne calibration doit être reprise après
changement de charge, de ballon, de câblage ou de configuration.

STOP/F10, fermeture de Navigation, intervention sur une entrée physique configurée
ou perte des permissions/propriétaire arrêtent le contrôle. Le maintien ne se
relance pas après cet arrêt. Un redémarrage applique le secours d'une session
interrompue ; il ne reprend pas automatiquement le vol. Save report conserve les
mesures une fois la session arrêtée. Apply candidate conserve le modèle pour une
utilisation ultérieure avec les validations habituelles ; cette sauvegarde
n'arme pas le contrôle.

## Vérifications hors Minecraft

Les tests utilisent un modèle de ballon avec hauteur d'équilibre dépendant de la
chauffe. Ils vérifient le seuil, la hauteur moyenne, les doublons, les trous, une
attente instable de 2 000 secondes sans abandon ni croissance mémoire, le refus
d'un modèle bruité et l'absence d'extrapolation. La chaîne de service vérifie les
retours de chaque brûleur, le secours nul avec preuve préalable, les pannes avant
le sweep, la persistance avant mouvement, le redémarrage interrompu et la reprise
manuelle. Sur ce modèle simulé, une consigne de 82 m entre les chauffes entières
converge à moins d'un mètre ; cela ne constitue pas une mesure dans Minecraft.

Les 154 suites passent sur le source et le paquet compact ; les 341 fichiers
source et les 155 chunks du runtime compact compilent. Le paquet est construit
pour le mode sans nouvel historique demandé. La migration exacte depuis 0.18.70
a un pic de 920 231 octets dans le test sans historique. Les tests
sous quota de 1 000 000 octets incluent 100 Ko de données utilisateur et les
interruptions de mise à jour. Une migration directe avec conservation volontaire
d'un checkpoint supplémentaire peut manquer d'espace ; le précontrôle la refuse
sans supprimer les sauvegardes existantes. Aucun essai de vol réel n'a été exécuté
ici. Tester d'abord sur une copie du véhicule, dans une zone dégagée, en vérifiant
les huit sections, les affichages texte/natif, les deux retours de brûleurs,
STOP/F10 et l'arrêt après perte de communication.
