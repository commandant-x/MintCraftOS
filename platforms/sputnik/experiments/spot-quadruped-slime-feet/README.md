# Quadrupède avec quatre pieds en slime

Chaque patte du quadrupède comporte désormais un bloc de slime à son extrémité. Il remplace le dernier bloc de bois du segment inférieur : chaque segment inférieur reste composé de sept blocs, chaque segment supérieur de sept blocs, et les douze pivots ainsi que l'unique moteur créatif sont conservés. Les quatre blocs font partie des sous-structures mobiles de leurs pattes ; leur présence a été [vérifiée après rechargement](slime-push/audit.txt).

[Télécharger le monde avec pieds en slime](quadrupede-pieds-slime.zip) · [Vue dans Minecraft](screenshots/quadrupede-pieds-slime.png). Extraire `Quadrupede-Pieds-Slime/` dans le dossier `saves` de VENATOR 1.0.0 avec tous ses mods, en conservant `sublevels/`. Le robot se trouve près de `40 182 42`, au départ de la piste de 250 blocs. Le moteur est enregistré à 0 tr/min ; Sputnik et ses 13 liaisons sont déjà configurés.

Pour l'essai, vérifier que les douze récepteurs d'embrayage reçoivent 15, régler le moteur créatif à 8 tr/min, puis cocher dans Sputnik « Armer les commandes redstone » et « Lancer les huit mouvements ». Décocher la seconde case avant une nouvelle séquence. Désarmer et arrêter le moteur après utilisation. La commande mémorise le cap et l'inclinaison à l'armement : armer le robot debout, orienté comme souhaité.

## Comparaison expérimentale

Les deux configurations ont été rechargées depuis des copies du même montage. Le banc utilise la même commande Sputnik, le même moteur à 8 tr/min et le même sol plat ; il actionne les cases sans joueur. Après sauvegarde et rechargement, les poses initiales diffèrent : environ 0,49 bloc en Z et 1,77° de cap.

| Essai | Pieds en bois | Pieds en slime |
| --- | --- | --- |
| Poussée latérale à l'arrêt : déplacement maximal du châssis pendant les 200 ticks suivants | 0,154 bloc | 0,168 bloc |
| Marche pendant 90 secondes de jeu : progression en Z | 7,19 blocs | 9,50 blocs |
| Marche : déplacement latéral | 1,20 bloc | 1,78 bloc |
| Marche : inclinaison maximale par rapport à la verticale | 1,75° | 1,78° |

Les deux essais de marche ont atteint la limite de durée prévue sans franchir le seuil d'arrêt ; les quatre pieds sont restés dans leurs structures assemblées. Les données et événements sont dans [wood-push](wood-push/analysis.json), [slime-push](slime-push/analysis.json), [wood-walk](wood-walk/analysis.json) et [slime-walk](slime-walk/analysis.json).

**Ces essais uniques ne démontrent pas une amélioration de l'adhérence.** La poussée a déplacé légèrement plus le châssis avec le slime dans cet essai ; la marche a progressé davantage mais avec une dérive latérale plus importante. Les positions ne mesurent ni les forces de contact ni un coefficient de frottement, et les différences de pose initiale ou du solveur peuvent influencer le résultat. Ni les 250 blocs ni la stabilité d'un Spot n'ont été validés.

La commande peut fermer les embrayages en cas de pose invalide ou de variation excessive d'inclinaison, mais elle ne coupe pas le moteur. Une perte de liaison peut engager un embrayage : le montage n'est pas un arrêt de sécurité matériel. Voir [la documentation de stabilisation](../spot-quadruped-balance/README.md) pour les détails et limites.
