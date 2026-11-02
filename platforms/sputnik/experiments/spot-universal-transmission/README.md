# Transmission de rotation entre deux structures Sable

La liaison testée ici est une **tige universelle du mod Create Aeronautics: Transmission & Linkage 0.2.9**, qui transmet le régime de rotation entre deux structures Sable. Elle est différente de la tige pneumatique essayée précédemment : j'avais choisi celle-ci à tort pour le rôle demandé par l'utilisateur.

Le banc construit sur le serveur Minecraft comporte deux structures Sable distinctes, une tête de liaison universelle sur chacune, une tige en laiton, un seul moteur créatif et un arbre récepteur. À 64 tr/min en entrée, les deux têtes et l'arbre récepteur indiquent 64 tr/min. Le banc a aussi été observé à 0 tr/min après arrêt du moteur, puis à 64 après redémarrage.

La deuxième structure a été repositionnée par le fixture **entre** les mesures, puis les deux structures ont été maintenues par le bâton physique pendant les relevés. La distance entre les têtes passe de 3 à 4 blocs, puis à environ 4,03 blocs avec 0,5 bloc de décalage latéral ; la transmission du régime reste observée. Ce test ne démontre pas la transmission en mouvement libre, sous charge, à toutes les orientations, ni la marche.

Les relevés sont dans [axial/trace.csv](axial/trace.csv) ; [lateral/trace.csv](lateral/trace.csv) conserve l'autre essai. Les sources exactes et l'analyse indépendante sont jointes. `python3 tools/minecraft-world-test/spot-universal/analyze.py axial/trace.csv` vérifie la séquence, le maintien, les distances et les quatre régimes. La reproduction nécessite le pack VENATOR fourni avec Transmission & Linkage 0.2.9 et un serveur jetable ; le fixture utilise le moteur créatif uniquement comme source.
