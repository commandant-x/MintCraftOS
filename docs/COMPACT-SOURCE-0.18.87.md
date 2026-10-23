# Sources compactes sans perte — 0.18.87

Prérequis de stockage pour poursuivre Ascendancy : la 0.18.86 approchait 1 Mo dans
le scénario avec rollback conservé. Ce changement récupère de l'espace sans
retirer de fonction, commentaire, chaîne de texte ou donnée personnelle.
Le lot A reste en cours ; aucun axe de pilotage supplémentaire n'est activé.

## Compatibilité Cobalt du pilote

La qualification réelle de l'interpréteur a aussi détecté une erreur du pilote
publié : la boucle de vol capturait 69 variables, au-delà de la limite Cobalt 60.
Les dépendances et l'état moteur privés sont regroupés ; la boucle n'en capture
plus que 55. Les lois de commande, consignes, permissions, retours et protections
restent identiques. Le simulateur avant/après émet exactement la même trace de
3 674 commandes Link. Ce correctif est une modification de code distincte du
réencodage sans perte et passe par la transaction normale.

## Installation et mise à jour

Après STOP, utiliser Update ou l'installateur épinglé indiqué avec la version.
L'installateur compare les sources **octet pour octet après décompression**.
Les modules fonctionnellement identiques sont réencodés un par un, avec la
transaction de récupération existante. Une coupure ne nécessite pas deux arbres
OS complets. La version et les véritables modifications de code ne sont appliquées
qu'ensuite, avec les contrôles et le checkpoint éventuellement choisis.

La phase `compact` indique cette préparation. Aucun balayage, signal moteur,
lecture de périphérique ou réarmement n'est ajouté. Les configurations, profils,
rapports, cartes, itinéraires, comptes et fichiers personnels sont conservés.
Aucun ancien checkpoint n'est supprimé sans la demande explicite déjà requise.
Le réglage sans nouvel historique reste le défaut.

Si le client ne possède que l'ancien callback de validation finale, la préparation
anticipée est désactivée : les encodages équivalents sont conservés, puis les
modifications réelles passent par son callback habituel. Le Computer fonctionne
avec un mélange des deux formats. Si l'espace ne suffit pas, cette voie refuse la mise à jour sans modifier le
code ; utiliser l'installateur manuel épinglé après STOP, ou un client autorisant
la préparation. Le client Update 0.18.86 possède déjà le callback nécessaire.

## Encodage et récupération

- LZSS borné, avec recherche plus profonde lors de la construction hors du jeu.
- Groupes de six octets sur sept caractères parmi 118 symboles ASCII. NUL,
  tabulations, retours à la ligne, ESC, DEL et les crochets sont exclus de cet alphabet.
- Les wrappers sont des sources Lua valides. Le décodeur vérifie les bornes,
  l'expansion, la longueur et le checksum. Ce checksum détecte la corruption ;
  il n'est pas une signature d'authenticité. La source de mise à jour reste le
  dépôt GitHub épinglé par commit et HTTPS.
- Les deux formats restituent exactement les sources, commentaires et données
  binaires compris. Le code de développement reste lisible dans Git.
- Le décodeur format 2 est autonome : un ancien module déjà chargé n'a pas à
  apprendre le nouveau format. Il est installé transactionnellement avant le
  premier réencodage. Le chargeur d'installation autonome est également lisible.
- `installer.lua` délègue à `installer_v2.lua`, unique implémentation courante.
  Le constructeur embarque directement cette implémentation pour une première
  installation ; il ne suppose pas qu'elle existe déjà sur le Computer.
- La persistance du réglage sans historique est elle aussi transactionnelle.
  Les champs personnalisés sont conservés. Une préparation refusée par le
  callback d'autorisation n'écrit ni code ni réglage.

Le protocole de journal 3 reste compatible avec le boot et la récupération
existants. Une préparation incomplète non ambiguë est récupérée ; un état sans
journal et sans marqueur valide reste conservé pour inspection, sans supposer
que ses sauvegardes peuvent être supprimées. Relancer l'installateur épinglé
après récupération. Ne pas effacer un répertoire de transaction au hasard.

## Retour à une version antérieure au format 2

Un installateur ancien essaierait de sauvegarder tous les wrappers différents,
même si leurs sources sont identiques. Sur un disque rempli, préférer l'outil
compatible depuis 0.18.87, après STOP :

```lua
wget run https://raw.githubusercontent.com/commandant-x/MintCraftOS/main/tools/rollback-compatible.lua 623e07685788b15b811440da3474ca440191fe6e
```

Cela restaure le comportement 0.18.86 via l'implémentation transactionnelle courante.
Pour ce commit précis, l'outil récupère aussi l'artefact Cobalt épinglé au commit
`a793160126533187717f1ee8795a234b0221e79c` : le pilote garde uniquement le correctif
structurel des 55 captures, car réinstaller la boucle originale échouerait dans
Cobalt. Cet artefact de transfert est hors de l'OS installé ; aucun second pilote
n'est actif. Les autres sources de ce retour restent celles du commit demandé.
L'outil télécharge le commit demandé et, pour ce retour connu, son correctif
Cobalt épinglé. Il capture le payload dans un
environnement restreint et **n'exécute pas son ancien installateur**. Les modules
dont les sources sont identiques gardent leur encodage compact ; les modules
réellement différents sont restaurés. Redémarrer ensuite. Utiliser de préférence
l'URL de l'outil épinglée fournie avec la livraison plutôt que `main`.

Les anciens rapports et fichiers utilisateur restent présents. Le décodeur format
2 demeure lorsqu'il est nécessaire aux applications conservées, y compris lors
d'une restauration de checkpoint via le service ou la récupération brute. Ce
petit lecteur de format n'est pas une copie d'une ancienne version de l'OS.
Le retour mesuré et qualifié ici est 0.18.87 → 0.18.86 avec correctif Cobalt → 0.18.87 ; les autres
anciens comportements de vol ne sont pas certifiés par ce test.

## Qualification

Les tests couvrent les deux décodeurs, données binaires, CRLF, commentaires,
retours/varargs, corruption, bornes, source équivalente, autorisation, client
ancien et coupures à chaque mutation sur les petites transactions. Des essais
supplémentaires migrent le véritable installateur 0.18.86 sur le disque simulé
1 000 000 octets, conservent 100 000 octets personnels, restaurent cette version
puis refont la mise à niveau. Résultats finaux dans le statut du projet.

Le décodeur et les wrappers ont aussi été vérifiés avec **Cobalt 0.9.9** extrait
de `cc-tweaked-1.21.1-forge-1.120.2.jar`, artefact disponible dans cet environnement :

- CC:Tweaked SHA-256 : `e8651fe24b384e925e563c9ad077644744474e2e7c0adb8e6d5b4757598dce9f`.
- Cobalt SHA-256 : `aca9fe1a2cab3ea7e296a72a1a6f667e29ddfdbab7af7cee35420bc2cc6e6929`.

`tools/VerifyPackedCobalt.java` compile les chunks et vérifie leur aller-retour
UTF-8 exact. `tools/build-packed-cobalt-probe.py` produit un probe autonome des
vecteurs du décodeur. Aucun binaire CC:Tweaked/Cobalt tiers n'est livré dans l'OS.
Les sources de tous les modules sont aussi décompressées, comparées à leurs
originaux puis compilées par Cobalt ; cette vérification a révélé la limite des
captures du pilote, corrigée avant publication. Les 168 sources du retour 0.18.86
avec correctif sont également compilées par cet interpréteur.
Cela ne remplace pas une validation serveur Minecraft : **essais en jeu non effectués**.
