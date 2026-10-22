# Adaptation de masse en vol — 0.18.80

Une variation de masse supérieure à 2 % pendant un maintien vertical qualifié
ne déclenche plus le secours pour ce seul motif. Le véhicule conserve sa consigne
d'altitude et apprend une correction progressive de chauffe à partir de l'erreur
réelle. La commande existante conserve son retour de vitesse verticale.
Aucun balayage, mouvement d'essai, test de secours ou impulsion moteur n'est lancé.

Le trajet horizontal est annulé et les moteurs désengagés : une modification de
masse peut aussi changer l'inertie ou la géométrie. Le modèle horizontal antérieur
n'est pas revalidé par une correction verticale, même si la masse revient à sa
valeur initiale. Le maintien d'altitude reste actif. Les commandes altitude seule
restent utilisables, dans l'ancienne plage mesurée. Reprendre une calibration
complète exige un STOP explicite ; elle ne se lance pas automatiquement en vol.

Si des tests étaient en cours alors qu'une table verticale qualifiée était déjà
utilisable, ils sont interrompus et le maintien reprend l'altitude effectivement
mesurée, si elle appartient à cette table. Sans modèle qualifié, cette adaptation
n'est pas disponible.

## Apprentissage local

- Une nouvelle masse valide, avec les mêmes unités et la même identité de
  véhicule, active l'adaptation. Les petites fluctuations sous le seuil ne
  réinitialisent pas l'apprentissage.
- La correction commence à sa valeur existante, sans saut calculé arbitrairement
  depuis le rapport de masses. Son évolution est limitée et ne se nourrit que de
  mesures d'altitude fraîches accompagnées d'un retour valide des récepteurs.
- L'intégration dispose d'un anti-emballement aux limites de chauffe. Après un
  changement de masse, le contrôleur peut utiliser les niveaux physiques 0–15,
  dans les limites configurées du canal, au lieu de rester enfermé dans les
  niveaux de l'ancienne table. La hauteur demandée n'est pas extrapolée.
- L'équilibre local est signalé sur huit observations espacées d'au moins 0,5 s :
  erreur et dispersion de hauteur au plus 0,5 m, vitesse verticale instantanée
  au plus 0,25 m/s et moyenne au plus 0,1 m/s. Le retour de récepteur à 1 Hz reste
  exploitable. Aucun délai fixe ne déclare la correction terminée.
- Le trim continue à corriger les perturbations après stabilisation. En limite
  de chauffe, il conserve la meilleure sortie disponible et indique l'autorité
  épuisée ; il ne prétend pas tenir une hauteur physiquement inaccessible.

L'écran Autopilot affiche la correction et son état. L'ancienne plage est
explicitement identifiée. La correction reste en mémoire pour cette session :
elle ne modifie ni les gains enregistrés, ni le rapport de calibration, ni les
preuves des tests physiques. Une stabilisation locale ne certifie pas une
nouvelle table complète ni la direction horizontale.

Une masse absente/non valide, un changement d'unité ou d'identité, la perte des
capteurs ou du retour des actionneurs, la reprise manuelle, STOP/F10 et la fermeture
de Navigation gardent leurs contrôles existants. Les dégâts qui détruisent une
commande ne sont pas assimilés à une simple variation de masse.

Maintenir une consigne fixe n'empêche pas un déplacement physique transitoire :
l'inertie thermique et le changement de portance peuvent produire un écart avant
correction. Les tests simulés couvrent une masse plus faible puis plus élevée,
le retour à la hauteur cible, l'interruption des tests en cours, la suspension
horizontale, les limites de commande et l'absence de faux certificat. Une
validation sur le vaisseau Minecraft reste nécessaire.
