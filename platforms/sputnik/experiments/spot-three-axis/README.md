# Spot expérimental : trois axes par patte, un seul moteur

Objectif demandé : quadrupède inspiré de Spot, avec trois rotations par patte (hanche latérale, hanche avant/arrière, genou), soit **12 axes**, alimentés par **un seul moteur créatif**. Cette page regroupe des essais préparatoires : **le robot n'est pas encore construit et aucune marche physique n'a été testée**.

## Nouveau mod et tige réelle

Le pack VENATOR fourni ajoute `Create Aeronautics: Transmission & Linkage 0.2.9` au pack antérieur, sans autre changement d'entrées ni de configurations. Son JAR a été vérifié avec le SHA-512 du pack. Il fournit notamment des têtes articulées, tiges pneumatiques et régulateurs alimentés mécaniquement et commandés en redstone.

Un banc Minecraft réel emploie **un seul moteur créatif**, une tige pneumatique normale, un régulateur et une structure mobile Sable ; il ne contient ni patte complète ni commande Sputnik. À 64 tr/min, le signal 0/15 commute la consigne entre 3 et 5 blocs. Une fois la structure déverrouillée, elle s'étend puis revient ; après arrêt du moteur, un signal 15 ne modifie plus la dernière consigne de 3 blocs. [Trace et analyse](straight-link/analysis.json).

Lors des premiers essais sans joueur, le retour ne se produisait plus. Le chargement explicite du chunk du banc et de la structure mobile a rétabli l'aller-retour : les [données de l'essai sans chargement forcé](unforced-link/analysis.json) sont conservées, et le fixture livré maintient ces zones chargées. Cela montre une condition nécessaire pour reproduire ce banc ; cela ne qualifie pas tous les comportements du mod.

## Tête articulée : mouvement observé, stabilité non acquise

Une tête articulée a été reliée au même type de tige, avec un axe Z. Le corps mobile n'est relié au support que par cette tige : il n'y a pas encore de pivot de hanche reliant rigidement les deux structures. Ce montage est donc sous-contraint et permet au corps de se balancer. Les consignes et le mouvement sont observés, mais l'extrémité oscille trop pour servir de patte pilotée :

| Retour / amortissement | Amplitude X pendant le retour | Amplitude maximale sur les 5 derniers échantillons | Critère de stabilité |
|---|---:|---:|---|
| 15 / 10 | 5,57 blocs | 5,57 blocs | non atteint |
| 4 / 20 | 3,33 blocs | 2,61 blocs | non atteint |

Les observations sont espacées de 10 ticks ; le critère exploratoire exige au plus 0,2 bloc de variation sur chaque axe dans les cinq derniers échantillons. Les valeurs ne sont pas une certification dynamique. [Essai initial](hinged-link/analysis.json) et [essai modifié](hinged-tuned/analysis.json), avec sources et CSV. La valeur plus faible du second essai ne suffit pas à valider une articulation. Les rôles et les limites physiques des pièces restent à mesurer.

## Banc avec pivot Simulated

Un autre banc relie un petit segment mobile à un pivot `simulated:swivel_bearing` et à une tige pneumatique, alimentée par le même moteur créatif unique. Le pivot est assemblé et la liaison pneumatique répond en consigne. La première configuration a été observée avec le pivot verrouillé ; une seconde a utilisé le réglage `UNLOCKED_ALWAYS` du pivot. Dans les deux cas, les angles mesurés en fin de phase à 5 blocs et à 3 blocs sont presque identiques : environ -43,9° puis -43,9° pour le pivot verrouillé, et -45° puis -45° pour le pivot déverrouillé. Le critère exploratoire exigeant au moins 5° de changement n'est pas atteint.

[Capture Minecraft du banc à un pivot et une tige](screenshots/banc-pivot-patte.png). La partie en bois est le segment mobile du banc ; elle ne représente pas une patte complète. La capture provient d'une copie du monde après le test, cadrée en spectateur.

Ces essais ne prouvent pas encore une hanche commandée : il reste à corriger la géométrie ou le réglage des contraintes, et à tester sous charge. Le banc montré est un seul segment articulé, pas une patte complète de Spot. [Données pivot verrouillé](pivot-diagnostic/pivot-analysis.json) · [données pivot déverrouillé](pivot-unlocked/pivot-analysis.json).

## Aperçu Sputnik des 12 angles

[TXT d'aperçu](spot-preview.clipboard.txt) : un nœud calcule quatre triplets d'angles à partir d'une phase et de dimensions abstraites. Il **n'écrit aucun Link ni moteur** ; `Walk qualified` vaut toujours 0. Ses sorties sont des angles mathématiques et ne doivent pas être branchées aux régulateurs sans calibration et contrôle physique.

Entrées : `Phase` (fraction de cycle), `Standing height`, `Stride`, `Foot clearance`, `Lateral amplitude`, `Upper leg` et `Lower leg` (blocs). Ordre des sorties : FL, FR, RL, RR, chacune avec `roll`, `hip` et `knee` en degrés. L'amplitude latérale produit un angle de hanche latérale pendant le lever du pied, avec un signe opposé à gauche et à droite. La trajectoire est un calcul de principe, pas un relevé de la géométrie d'un robot. Si une cible est inaccessible, `Geometry valid` passe à 0 et les sorties sont remises à zéro.

Les tests exécutés en Lua 5.2 et dans LuaJ Cosmonautics vérifient 291 cibles de cinématique inverse/directe, 1 001 échantillons de trajectoire, le rejet des entrées impossibles et la sortie des 12 angles. Le TXT a été vérifié par le parseur SNBT et la sérialisation NBT Minecraft/Sputnik. Aucun de ces tests ne prouve la marche dans le monde.

Le calcul de triangle d'appui séparé montre aussi que, pour une disposition symétrique de quatre pieds, le centre peut tomber exactement sur le bord du triangle quand une patte est levée : il faut donc prévoir un transfert de masse et mesurer les contacts. La stabilité, les collisions, les limites d'angle, les liaisons entre segments, la distribution du moteur unique vers douze axes et les vrais signaux Link restent à développer et tester.

Le banc est dans [`SpotLinkageProbe.java`](../../../../tools/minecraft-world-test/spot-linkage/SpotLinkageProbe.java), les empreintes dans [provenance.json](provenance.json), et l'analyse est reproductible avec `python3 tools/minecraft-world-test/spot-linkage/analyze.py CHEMIN_CSV`. Les réglages de la tige normale ne sont pas des paramètres validés pour un robot Spot complet.
