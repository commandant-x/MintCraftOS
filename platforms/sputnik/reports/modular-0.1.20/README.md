# Hélices modulaires — Sputnik 0.1.20

Simulation indépendante du paquet livré, exécuté dans le LuaJ de Cosmonautics
26.08.307. **Aucun vol Minecraft réalisé ; aucune géométrie ni inertie réelle du
nouveau véhicule n’a été déduite de sa photo.** Les masses/inerties ci-dessous
sont des paramètres du banc ; en jeu le contrôleur lit les API natives.

## Correction

Le modèle précédent traitait chaque rotor comme une petite hélice de poussée
`RPM × pression`. Dans Aeronautics 1.3.2, le Propeller Bearing utilise au contraire
`N^1,5 × RPM × 0,2`, et un airflow `√N × RPM × 0,05`, pour N blocs reconnus comme
voiles. À 12 voiles, le coefficient de poussée vaut environ **8,314** et celui
d’airflow **0,1732**, contre 1 et 0,1 pour une petite hélice standard. Une masse
correctement lue ne corrige pas à elle seule cette erreur de modèle.

La mise à jour fournit quatre comptes configurables, par champs sauvegardés ou
entrées numériques. Le modèle calcule pression, équilibre et sensibilité pour
chaque rotor ; la réserve de poussée et les gains utilisent les coefficients
individuels. L’amortissement d’attitude des bearings utilise les gains de vitesse
8 et d’accélération 1,2 ; les petites hélices conservent 4,5 et 0,6. Ces valeurs
sont expérimentales, pas un réglage universel identifié automatiquement.

Le banc applique séparément les formules Java auditées, la rampe de régime
`alpha = 0,4 / √N` par tick, l’écoulement local incluant `omega × bras`,
les forces ponctuelles, les couples et la dynamique quaternion à 200 Hz.
Le contrôleur fonctionne à 20 Hz avec propagation du graphe et retard radio.
La plante ne réutilise pas la fonction de poussée ou d’allocation du contrôleur.

## Résultats du contrôleur livré

| Hypothèse de montage | Références réussies | Tous les cas |
| --- | ---: | ---: |
| 12/12/12/12 voiles, 32 kg, bras 3/5 m, inerties 250/400/230 | **36/41** | 38/50 avec les stress |
| 12/12/12/12, 65 kg, mêmes bras/inerties, 7 essais ciblés | **7/7** | 7/7 |
| 12/12/12/12, 200 kg, bras 5/8 m, inerties 1000/1600/920, 7 essais ciblés | **7/7** | 7/7 |
| 8/12/16/20, 32 kg, bras 3/5 m, inerties 250/400/230 | **5/6** | 5/6 |

Les sept essais ciblés sont maintien, inclinaison initiale en tangage/roulis,
montée puis maintien, avance puis freinage, perte de masse et virage de trajectoire.
Le jeu hétérogène omet le roulis initial. Les CSV et JSON de chaque série sont
conservés avec les empreintes du contrôleur et de la plante.

La version intermédiaire avec seulement les bons coefficients, avant renforcement
de l’amortissement, obtenait **28/41** références. Elle est conservée dans
`coefficients-only-before-damping` et n’est pas la version livrée.
L’avance maintenue 20 s échouait alors (inclinaison > 25°). Avec le contrôleur
livré, elle passe : inclinaison maximale **16,57°**, erreur finale altitude
**0,0058 m** et vitesse finale **0,0178 m/s**. Les sorties ne sont pas limitées
par un plafond arbitraire de vitesse.

## Limites visibles, pas masquées

Les cinq références qui échouent à 32 kg sont : délai radio 4 ticks, inertie
au quart, au huitième, au quart avec délai 2 ticks, et avance avec inclinaison
réglée à 15°. Cette dernière déclenche encore la protection de l’enveloppe.
Les voiles de tailles différentes ont encore un échec sur le maintien horizontal
après perte de masse, malgré une altitude tenue. **Le support du calcul par rotor
ne prouve donc pas une stabilisation universelle de toutes les combinaisons.**
Les faux branchements, émissions concurrentes, centre de masse décalé, rotor
faible et course extrême ont aussi des échecs conservés dans la série complète.

Le banc n’inclut pas les collisions, les contraintes/joints, la résolution des
réseaux Create, les gyroscopes des rotors ni un tenseur complet hors diagonale.
Il ne confirme ni l’assemblage des bearings ni le sens réel de poussée.
L’API native ne donne pas le nombre de voiles derrière une fréquence Link :
les quatre valeurs sont **configurées**, sans lecture fictive du matériel.

## Reproduire

Utiliser `tools/test-sputnik-twin.py` avec les chemins vers le JAR Cosmonautics
et Java 21, puis `--mass 32 --arm-x 3 --arm-z 5 --height 1 --sails 12,12,12,12`.
Omettre `--cases` exécute les 50 scénarios, y compris tous les stress.
`tools/test-sputnik.py` vérifie aussi les fixtures natives, le format réel
SNBT/NBT/payload et trois régressions modulaires avec assertions : inclinaison
initiale, avance maintenue 20 s, perte de masse. Une réussite de cet outil ne
transforme pas les échecs de la batterie étendue en réussites.
