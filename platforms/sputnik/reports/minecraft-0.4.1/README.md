# Essais réels Minecraft — Sputnik 0.4.1

Le grand quad de la sauvegarde VENATOR a été chargé et piloté sur un vrai serveur Minecraft 1.21.1 / NeoForge 21.1.264, avec les versions du pack fourni. Les mouvements ci-dessous utilisent les blocs réels, les récepteurs Link et le solveur Rapier/Sable. Ce ne sont pas les résultats du jumeau numérique.

## Montage et protocole

Masse exposée 193,5 kg ; quatre Propeller Bearings, chacun 12 voiles, source 256 RPM. Les coordonnées, sens de poussée et associations des fréquences ont été relevés avec le mod de test. Le graphe sauvegardé était vierge : groupes désactivés, fréquences absentes, rayon manquant. Le test configure sa copie avant OFF/ON. Cette préparation instrumentée ne constitue pas une nouvelle fonction de scan du Lua distribué.

Le véhicule est retenu par le bâton physique pendant la préparation et la mise au trim. Après réarmement, ce verrou est retiré : seuls les moteurs du contrôleur agissent pendant les mesures. Les touches sont injectées par un nœud de test sur les fréquences radio ; les boutons du clavier physique et le rendu client ne sont pas testés. Le mode Q/D est latéral. Chaque impulsion dure 20 ticks, avec retour au maintien entre les mouvements. Le contrôleur conserve l’unique propriété des fréquences moteur.

Un critère PASS exige le mouvement dans le sens demandé, l’achèvement de la phase, puis **60 observations consécutives fraîches** en fin de phase : erreur d’altitude ≤ 1 m, |Vy| ≤ 0,1 m/s, vitesse horizontale ≤ 0,2 m/s, |tangage| et |roulis| ≤ 5°. Une pause horizontale nécessitant acquittement empêche PASS. Les pointes pendant la manœuvre sont publiées séparément.

## Résultats

| Mouvement | Ancien détecteur | Détecteur corrigé | Erreur altitude max dans la phase (m) | Erreur max des 3 dernières secondes (m) |
| --- | --- | --- | ---: | ---: |
| hover | PASS | PASS | 0.331 | 0.009 |
| climb | PASS | PASS | 1.668 | 0.061 |
| descend | PASS | PASS | 1.334 | 0.028 |
| forward | PROTECTED | PASS | 0.165 | 0.002 |
| reverse | PROTECTED | PASS | 0.132 | 0.005 |
| left | PROTECTED | PASS | 0.157 | 0.010 |
| right | PROTECTED | PASS | 0.124 | 0.011 |
| diagonal | PROTECTED | PASS | 0.235 | 0.017 |

Le maintien final reste sous 7 cm dans cette série. **La montée et la descente dépassent un mètre d’erreur transitoire** : ce résultat ne valide pas un maintien sous un mètre pendant toute manœuvre. Le cap du nez reste non contrôlé ; sa dérive cumulée mesurée est d’environ 132°. Le pilotage horizontal est exprimé dans le repère du véhicule et ne certifie pas la tenue d’un cap du nez.

Les traces complètes et PDF à huit pages sont dans `before-supervisor/` et `after-supervisor/`. Les vitesses et les niveaux réellement reçus par les quatre Links figurent dans `flight.csv`, ainsi que les régimes effectifs des hélices. Les deux passages sont comparables mais pas bit pour bit : la physique réelle et la séquence de quantification ne sont pas déterministes à ce niveau. Aucun gain PID, modèle de force ou calcul de stabilisation n’a été changé pour obtenir ces résultats.

## Corrections vérifiées

1. **Provenance du journal.** La résolution de `fallback=-1` en trim moteur ne doit pas remplacer l’empreinte du descripteur déclaré par celle du repli matérialisé. Le rapport actif utilise les groupes figés du contrôleur. Le défaut échoue dans le vrai LuaJ avant correction et passe ensuite. Un export du vrai serveur, en trois pages et 289 observations, est vérifié indépendamment par le parseur Python avec contexte concordant.

2. **Protection après freinage amorti.** L’ancien détecteur conservait un pic de 30,89° dans sa fenêtre de six secondes alors que l’amplitude récente avait fortement diminué. Il verrouillait le déplacement après retour au calme. Le détecteur conserve 120 observations, mais exige une amplitude encore présente dans les 60 dernières pour déclarer l’oscillation et la protection. Les seuils persistants restent inchangés. Un extrait de 120 observations réelles est un test de régression ; les oscillations sévères synthétiques restent détectées. Le passage réel corrigé ne nécessite aucun acquittement entre les mouvements.

Le modèle et l’allocation des moteurs restent ceux de la 0.4.0. Ces corrections ne sont pas un réglage FPV plus rapide.

## TXT configuré et reprise

[TXT complet préparé pour le grand quad de cette sauvegarde](venator-quad-configured.clipboard.txt). Il contient sept nœuds, quatre groupes renseignés et les fréquences relevées. Le nœud émetteur de touches du banc de test n’est pas inclus. Le lien manquant de géométrie brouillon vers l’afficheur a été rétabli : le monde essayé avait 33 connexions, le TXT fourni en a 34, sans changement de chaîne de commande moteur. Le TXT est vérifié par les vrais parseur SNBT, sérialisation NBT et codec Sputnik.

Passer le levier OFF, retirer l’ancien graphe puis importer ce TXT dans le fond de l’éditeur ; ne pas conserver deux contrôleurs sur les mêmes fréquences. Ce montage est spécifique à ce quad et à ses récepteurs. Les paramètres mécaniques restent à revérifier si le véhicule change.

## Reproduction et limites

Les sources du fixture et du compilateur portable sont dans `tools/minecraft-world-test/`. Le compteur de fin par défaut est 4 000 ticks. Le fixture retient ensuite le véhicule, remet Enable OFF et collecte le journal avant l’arrêt du serveur. Un défaut de nettoyage de la première version du fixture déclenchait ABORT au tick 4 001 après le COMPLETE du tick 4 000 ; cet événement brut est conservé. Il ne s’agit pas d’une sortie de l’enveloppe pendant le vol. Le nettoyage et l’export ont ensuite été vérifiés dans un passage réel court dédié, avec le fixture corrigé. Le score distingue les défauts en phase et ceux du nettoyage.

Aucun joueur n’était à bord ; ses contacts et son poids extérieur ne sont pas couverts. Les essais ne valident ni charge suspendue, ni changement de masse/COM en vol, ni retournement, ni démarrage à froid, ni les autres architectures. Ils n’utilisent pas les collisions comme critère d’atterrissage et ne garantissent pas l’évitement du terrain. Le drapeau de qualification globale reste faux. Les avertissements de compatibilité optionnelle CBC/copycats et les vérifications de version du pack n’ont pas empêché le chargement ; leur présence n’est pas masquée par un succès global du modpack.

La sauvegarde, les inventaires, les données des joueurs et les mods tiers ne sont pas redistribués. Les empreintes des six volumes d’entrée sont dans `validation.json` ; seuls les mesures nécessaires, les sources du fixture et le TXT préparé sont publiés. Les originaux extraits restent séparés des mondes de travail.
