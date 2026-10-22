# Navigation 0.18.70 — détection et huit espaces de travail

Navigation présente désormais huit onglets principaux : Flight, Route,
Equipment, Vehicle / setup, Altitude, Outputs, Sensors et Control. Les outils
spécialisés restent accessibles dans leur section : schéma/analyse et anciennes
estimations dans Vehicle, tests physiques et PID dans Altitude, entrées manuelles
dans Outputs, environnement dans Sensors. Ils conservent leurs clients natifs et
leur secours texte.

## Parcours

1. Connecter le bridge et ouvrir Vehicle / setup. Le cache réel fournit le nom,
   le type suggéré, le nombre de rotors, la masse avec son unité et le centre de
   masse lorsque la géométrie est complète. Les mesures sont en lecture seule ;
   Manual override permet une configuration manuelle. Aucune saisie du nom du
   périphérique n'est nécessaire pour le découvrir.
2. Ouvrir Burner setup. Les brûleurs, la paire de fréquence et le transmetteur
   unique sont préremplis sur une seule page. Si le bridge devient disponible
   après l'ouverture, la page se remplit au rafraîchissement. Plusieurs
   transmetteurs demandent un choix ; les réglages déjà choisis sont conservés.
3. Vérifier le groupe et le câblage réels, puis Review + Save. La confirmation
   indique groupe, transmetteur, fréquence et signaux. Enregistrer n'émet aucun
   signal. La configuration existante n'est remplacée qu'avec accord explicite.
4. Utiliser Altitude pour les validations, la mesure, le candidat et la consigne.
   Les commandes de vol et les validations physiques restent explicites.

Dans Outputs, les transmetteurs détectés et les paires des récepteurs du véhicule
sont proposés directement. Une valeur manquante sans ambiguïté est préremplie
et appliquée seulement lors de Save. Plusieurs possibilités ne sont jamais
choisies automatiquement. Les couleurs des fréquences sont conservées. Une paire
existante non détectée reste conservée ; Manual entry permet une saisie de secours.

Les choix se parcourent par clic ou Entrée ; les cases se cochent directement
ou avec Espace. Tab passe au contrôle suivant. Ces contrôles n'ouvrent pas de
clavier de texte et refusent frappe/collage/effacement. Les valeurs numériques et
les noms libres restent des champs de texte. STOP / F10 reste accessible même
si une saisie est invalide.

## Limites de l'automatisation

La découverte lit les caches existants : aucun nouveau balayage permanent des
périphériques. Une géométrie périmée ou d'un autre véhicule n'est pas présentée
comme une mesure actuelle. Les sorties, le sens du câblage, la reprise manuelle,
le secours et la réponse physique ne se déduisent pas de la présence du bridge.
Aucun armement, test de chauffe ou mouvement automatique n'est ajouté.

## Vérification

Les régressions couvrent connexion tardive, retrait des mesures périmées,
identité/type/masse préremplis, absence d'écriture à la consultation, huit onglets,
valeurs uniques ou ambiguës, conservation des couleurs, contrôles clic/clavier,
lecture seule, calibration et confirmation du sweep, annulation et STOP.
L'installeur compact est régénéré ; les mesures de quota incluent 100 Ko de données
utilisateur et la migration exacte depuis 0.18.69 : 844 028 octets après
installation, pic de 930 050 octets pendant la migration avec retour arrière
activé, sous le quota de 1 000 000 octets. Les interruptions pendant la sauvegarde
et les écritures sont récupérées. Les 154 suites passent sur le code source et
le paquet compact ; 340 fichiers source et 154 chunks du runtime compact compilent.
Ces mesures utilisent un disque simulé conservateur avec minimum de 512 octets
par fichier/répertoire, pas le disque personnel d'un joueur. Aucun nouvel historique
permanent n'est créé par défaut.

À vérifier dans Minecraft : connecter/déconnecter le bridge avec Navigation
ouverte ; essayer un puis deux transmetteurs et plusieurs fréquences ; vérifier
les mesures et l'enregistrement ; parcourir les huit sections en mode natif et
texte. Sur une copie du véhicule, vérifier les commandes physiques et STOP/F10.
Ces essais dans Minecraft n'ont pas été exécutés dans l'environnement cloud.
