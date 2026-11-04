# Prototype d'une patte à trois pivots

Cette construction Minecraft est un **banc d'une seule patte** pour le robot quadrupède inspiré de Spot. Elle comporte trois `swivel_bearing` Simulated, avec un premier axe Z (hanche latérale) et deux axes X (hanche avant/arrière et genou), trois segments en bois et un seul moteur créatif placé au sommet. [Capture prise dans Minecraft](screenshots/patte-3-pivots.png).

Les trois pivots ont été assemblés dans Minecraft et les trois structures Sable correspondantes restent présentes dans le monde enregistré ([relevé](assembled/audit.txt)). Pendant cette vérification, elles étaient maintenues par le bâton physique et le moteur était à **0 tr/min**. Les liaisons universelles et les commandes pour entraîner les trois axes ne sont pas encore installées sur cette patte. L'assemblage ne prouve donc ni mouvement commandé, ni portance, ni marche.

Le [monde du banc](spot-patte-trois-pivots-monde.zip) contient une copie de cette construction. Extraire le dossier qu'il contient dans `saves` de l'instance VENATOR utilisant le nouveau mod Transmission & Linkage 0.2.9. Le moteur y est à l'arrêt et les structures ont été enregistrées verrouillées ; c'est un prototype de visualisation et de montage, pas une patte prête à marcher. La capture provient d'une copie du même monde ouverte dans le client Minecraft. Les métadonnées du fixture serveur ont été retirées de la copie fournie.

[Essai séparé de transmission avec une seule source](../spot-universal-transmission/README.md) : la liaison en laiton transmet le RPM entre deux structures Sable, mais cette liaison n'est pas encore montée sur la patte ci-dessus. Les quatre pattes du robot, le transfert de puissance vers les axes, leur contrôle Sputnik et la marche restent à construire et à tester.
