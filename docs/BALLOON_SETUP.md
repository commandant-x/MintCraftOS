# Ballon : assistant de configuration

Le pont Vehicle Bridge 0.2.1 detecte les bruleurs Aeronautics sur le sublevel,
leur signal et leur association a un ballon. Discover ouvre le guide lorsqu'il
en trouve. Sans ce pont, aucune detection de bruleur n'est inventee.

1. Ouvrir Navigation, Vehicle, Discover puis confirmer l'import.
2. Le guide propose une seule paire d'items pour la chauffe collective.
   Il reprend une paire de recepteurs adjacents commune si possible ; sinon
   il propose une paire de laines non vue localement. Ce n'est pas une
   reservation globale : verifier les autres machines a portee.
3. Configurer cette paire sur les recepteurs Create relies aux bruleurs.
   Un transmetteur CC:Create Redstone Link doit etre visible du PC.
4. Choisir le transmetteur, le signal stationnaire mesure, le signal de secours
   et le sens du cablage. Confirmer les branchements. Le remplacement d'un
   ancien mapping demande un accord explicite.
5. Apply + Save enregistre sans emettre. Effectuer ensuite la calibration
   physique et regler les gains PID d'altitude, initialement nuls.

## Association Aeronautics Non Initialisee

Le pont 0.2.0 confondait l'association avec ServerBalloon.isValid(), qui teste
en realite les volumes de gaz courant/cible (> 0,05), pas la liaison du
bruleur. Le pont 0.2.1 verifie une reference de ballon, une capacite positive
et la presence du bruleur dans ses heaters. L'etat du gaz est exporte
separement comme gasActive et ne conditionne pas cette association.
Un ballon vide peut donc etre associe sans etre actuellement porteur.

Dans Aeronautics 1.3.2, la recherche du ballon est effectuee par le lazy tick
du bruleur (20 ticks de jeu), uniquement lorsqu'il peut emettre du gaz.
Le test generique de 0,3 seconde peut donc terminer avant cette recherche.

Dans Calibration, choisir un Test signal non nul physiquement verifie, puis
Initialize (2s). La confirmation indique le signal et le retour au secours.
Ce test dure deux secondes au maximum, ne se repete pas automatiquement et
ne force aucune association. Apres sa fin, Rescan puis verifier les etats des
bruleurs. Il ne valide ni les gains, ni le stationnaire, ni le secours physique.

Si l'association reste absente avec un signal positif, verifier avec les
lunettes d'ingenieur Aeronautics si le bruleur reconnait une enveloppe valide.
Verifier son degagement vertical, la portee configuree et l'enveloppe ; ne pas
contourner la verification en armant un bruleur non reconnu.

Au bruleur Aeronautics, 0 coupe l'apport de gaz et 15 correspond au maximum
configure. Le cablage externe peut inverser ce comportement. La coupure ne
vide pas instantanement le ballon et ne garantit pas une descente sure.

Ce mode collectif maintient uniquement l'altitude : il ne stabilise pas le
roulis, le tangage ou le cap. La position d'un bruleur n'est pas le point
d'application de la flottabilite. La detection ne valide ni le cablage, ni les
gains, ni la consigne de secours. Aucun test, armement ou reglage de gain
automatique n'est effectue par le guide.


### V0.18.50 diagnostics

The guide now shows current bridge status/version and bounded bridge errors,
plus each burner signal (0–15), gas output, balloon association and gas activity
as separate facts. A structurally associated empty balloon is not reported as
missing. These readings do not certify hover, wiring or safe rescue behaviour.
A complete Java inventory may be used for the burner wizard even when COM or
propeller direction is unavailable; this does not enable physical model import.
Missing bridge, stale data and truncated scans still refuse discovery/setup.
Install the 0.2.1 JAR on server and clients and restart; the OS installer cannot
install a Minecraft mod. Use Rescan, then Detect to rebuild a proposed mapping.
