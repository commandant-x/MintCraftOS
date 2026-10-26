# Quad FPV 0.3.0 — domaine testé

Contrôleur rapide séparé, quatre hélices modulaires identiques. Ces essais exécutent le Lua distribué dans le LuaJ réel de Cosmonautics. Ils ne constituent pas des essais Minecraft.

| Banc | Résultat | Conséquence |
| --- | --- | --- |
| Référence 32 kg, 12 voiles par rotor, bras 3/5, inerties 250/400/230, retard 1 tick | 12/12 | Maintien, montée, freinage, redressement et charges de référence passent |
| Inertie ×0,25, retard 2 ticks, bruit 0,01 m | 2/4 | Charges oscillantes/décentrées non validées |
| Corde 10 m, charge 32 kg | 2/3 | Maintien et largage passent ; balancement initial non amorti suffisamment |
| Contrôleur standard inchangé, mêmes consignes et banc, sous-ensemble comparatif | 0/4 | Montée rapide non atteinte, freinage plus lent, inversion refusée, charge cachée non compensée à altitude constante |

Montée : 90 % de 4 m/s en 0,85 s. Freinage : 4 s contre 6,7 s dans le comparatif. Ces temps dépendent de la vitesse obtenue avant relâchement, des modèles moteur et du pas de calcul. Les CSV donnent également la vitesse au relâchement et le temps de prise d'inclinaison.

Le redressement de 150° perd jusqu'à 18,3 m avant de remonter ; aucune conservation d'altitude pendant une inversion n'est revendiquée. Les scénarios commencent au régime de sustentation connu, pas avec des rotors immobiles au sol. Le démarrage réel, les contacts et les cordes Minecraft restent à tester progressivement.

Les échecs sont conservés. Chaque sous-dossier contient les critères, paramètres, empreintes et sorties. Les zéros des temps signifient non observé/non applicable. Les anciens rapports universels concernent exclusivement le contrôleur standard, dont le SHA-256 reste `f62be0b6c8615597f61518f218198dac66afd645daa89562344c7039dcec4092`.
