# Ballon : assistant de configuration

Le pont Vehicle Bridge 0.2.0 detecte les bruleurs Aeronautics sur le sublevel,
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

Au bruleur Aeronautics, 0 coupe l'apport de gaz et 15 correspond au maximum
configure. Le cablage externe peut inverser ce comportement. La coupure ne
vide pas instantanement le ballon et ne garantit pas une descente sure.

Ce mode collectif maintient uniquement l'altitude : il ne stabilise pas le
roulis, le tangage ou le cap. La position d'un bruleur n'est pas le point
d'application de la flottabilite. La detection ne valide ni le cablage, ni les
gains, ni la consigne de secours. Aucun test, armement ou reglage de gain
automatique n'est effectue par le guide.
