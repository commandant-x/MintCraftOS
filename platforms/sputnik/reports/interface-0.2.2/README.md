# Sputnik 0.2.2 — interface simplifiée

Le contrôleur physique est identique octet pour octet à celui de la 0.2.0. Le contrat MCV1 reste complet : les réglages courants ont des champs simples, les autres sont accessibles par `cle=valeur` dans Expert et par import/export intégral. Les anciens formulaires détaillés restent disponibles dans le graphe universel avancé.

| Graphe | Widgets créés en 0.2.1 | Widgets créés en 0.2.2 |
| --- | ---: | ---: |
| Quad | 308 | 197 |
| Ballon | 308 | 200 |
| Venator | 424 | 261 |
| Hélicoptère | 308 | 200 |

Ces comptes proviennent de la fixture LuaJ ; ils ne constituent pas une mesure de FPS dans Minecraft.

## Changements

- Noms des moteurs et rôles préchargés. Le type est arrondi et son nom affiché.
- Champs Position séparés ; poussée verticale automatique, sans champ Direction adjacent susceptible d’être confondu avec une position.
- Fréquence puissance, RPM, voiles et moteurs partageant la commande restent accessibles. Clutch facultatif ; inverseur affiché pour les groupes de propulsion.
- Paramètres expert et toutes les propriétés MCV1 préservés dans l’échange complet.
- Agrégateur simple sans interrupteur d’import global vide ; les formulaires sont toujours sa source.
- Boutons nommés pour maintien, altitude, vitesse/cap, essais et pauses/reprises. Routes, bibliothèque et commandes avancées conservées.
- Diagnostic des nombres, direction non unitaire, fréquence incomplète, voiles et régime dans le formulaire moteur. Domaine des réglages généraux expliqué près de la saisie, sans modification silencieuse des consignes.

## Validation

Les quatre graphes passent le démarrage OFF/ON, le refus de démarrage déjà ON, le contrôle de l’émetteur unique et les consignes en vol sans perte de l’estimateur. Les tests supplémentaires couvrent les boutons nommés, le type fractionnaire, les directions automatiques, le refus d’un import vide sans destruction de la configuration, et un aller-retour complet de coefficients/repli/clutch expert.

La suite complète de régression passe avec le même contrôleur physique. Les dernières modifications de saisie sont couvertes par la suite interface, les fixtures LuaJ réelles et les 30 imports SNBT/NBT/codec Sputnik. Une vérification complémentaire utilise les vrais champs texte et sliders natifs : RPM, voiles, membres, XYZ, paramètres expert et copie restent identiques après création d’un nouvel évaluateur et rechargement du tag natif. Les item pickers sont neutralisés dans ce test natif sans serveur ; leurs valeurs sont testées séparément dans les fixtures LuaJ d’import/export. Les journaux et empreintes sont joints.

Aucun nouveau domaine de vol n’est qualifié et aucun essai de FPS ou de vol dans Minecraft n’est annoncé. Les échecs conservés restent ceux du [rapport numérique](../universal-0.2.0/README.md).
