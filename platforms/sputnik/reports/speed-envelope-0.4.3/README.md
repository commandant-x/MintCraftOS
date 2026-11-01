# Vitesses mesurées dans Minecraft — Sputnik 0.4.3

46 directions sur six constructions natives. Les valeurs sont les meilleures vitesses mesurées avec croisière stable **et freinage validé** dans cette campagne. Un tiret signifie aucune vitesse prouvée par ce protocole, pas une impossibilité de voler.

| Construction | Direction | m/s | km/h | Freinage (s) | Excursion horizontale (blocs) | Perte altitude au freinage (blocs) |
|---|---|---:|---:|---:|---:|---:|
| octo | forward | — | — | — | — | — |
| octo | reverse | 18.83 | 67.80 | 12.40 | 68.11 | 0.33 |
| octo | left | 15.08 | 54.30 | 11.55 | 47.61 | 0.32 |
| octo | right | 5.33 | 19.18 | 9.20 | 10.40 | 0.27 |
| octo | forward_left | 3.24 | 11.65 | 8.40 | 5.26 | 0.29 |
| octo | forward_right | 3.81 | 13.71 | 8.45 | 6.24 | 0.32 |
| octo | reverse_left | 15.08 | 54.28 | 11.75 | 48.03 | 0.32 |
| octo | reverse_right | 14.64 | 52.70 | 11.40 | 45.12 | 0.34 |
| octo | up | 3.94 | 14.17 | 3.25 | 0.47 | 0.00 |
| octo | down | 3.04 | 10.94 | 3.80 | 0.28 | 2.23 |
| quad | forward | 7.30 | 26.30 | 10.40 | 17.47 | 0.32 |
| quad | reverse | 29.12 | 104.85 | 15.25 | 142.19 | 0.36 |
| quad | left | 29.12 | 104.84 | 15.25 | 142.09 | 0.36 |
| quad | right | 3.42 | 12.31 | 8.90 | 5.89 | 0.17 |
| quad | forward_left | 29.12 | 104.82 | 22.05 | 142.04 | 0.35 |
| quad | forward_right | 4.08 | 14.70 | 9.15 | 7.24 | 0.25 |
| quad | reverse_left | 29.12 | 104.82 | 21.70 | 142.01 | 0.36 |
| quad | reverse_right | 29.12 | 104.83 | 21.55 | 142.16 | 0.36 |
| quad | up | 4.96 | 17.87 | 5.90 | 0.81 | 0.00 |
| quad | down | 3.15 | 11.35 | 4.85 | 0.24 | 2.29 |
| quad-turns | forward | 13.83 | 49.79 | 8.80 | 33.83 | 0.01 |
| quad-turns | reverse | — | — | — | — | — |
| quad-turns | up | 3.96 | 14.27 | 5.30 | 0.96 | 0.00 |
| quad-turns | down | 3.00 | 10.79 | 4.85 | 0.85 | 2.29 |
| balloon-lift | up | 3.80 | 13.67 | 20.35 | 0.01 | 8.11 |
| balloon-lift | down | 4.77 | 17.15 | 9.10 | 0.01 | 9.27 |
| hex | forward | — | — | — | — | — |
| hex | reverse | 18.83 | 67.78 | 12.45 | 68.01 | 0.28 |
| hex | left | 18.81 | 67.73 | 12.45 | 67.90 | 0.28 |
| hex | right | 7.49 | 26.95 | 9.80 | 16.04 | 0.20 |
| hex | forward_left | 5.34 | 19.24 | 9.30 | 10.57 | 0.20 |
| hex | forward_right | 3.97 | 14.31 | 8.65 | 6.52 | 0.32 |
| hex | reverse_left | 15.11 | 54.40 | 11.65 | 48.15 | 0.28 |
| hex | reverse_right | 18.39 | 66.21 | 12.50 | 65.23 | 0.33 |
| hex | up | 4.96 | 17.85 | 5.20 | 0.58 | 0.00 |
| hex | down | 3.18 | 11.45 | 4.20 | 0.22 | 2.23 |
| tri | forward | 7.31 | 26.32 | 5.00 | 19.01 | 0.07 |
| tri | reverse | 29.27 | 105.38 | 9.65 | 147.14 | 0.40 |
| tri | left | — | — | — | — | — |
| tri | right | — | — | — | — | — |
| tri | forward_left | — | — | — | — | — |
| tri | forward_right | — | — | — | — | — |
| tri | reverse_left | — | — | — | — | — |
| tri | reverse_right | — | — | — | — | — |
| tri | up | 4.97 | 17.90 | 6.50 | 0.72 | 0.00 |
| tri | down | 4.00 | 14.41 | 4.90 | 0.43 | 2.90 |

## Portée et limites

Minecraft 1.21.1, NeoForge 21.1.264, mods du pack VENATOR fourni. Serveurs sans interface graphique : physique et blocs réels, commandes publiques Sputnik et fréquences Link. Aucun test de touches physiques ni de client multijoueur. Les véhicules sont les six constructions du banc 0.4.2 ; hélicoptère, avion et V22 ne sont pas inclus.

Inclinaison configurée 20°, commandes verticales 1 à 5 m/s ; recherche horizontale 2 à 64 m/s, puis jusqu’à trois affinages. Ces résultats bornent le comportement de ce pilote et de ces montages, et ne constituent pas une vitesse maximale physique absolue. Une première tentative à 2 m/s qui échoue ne prouve rien sur les vitesses inférieures. Un échec de freinage ne fournit aucune vitesse confirmée. Le quad avec propulsion dédiée est testé à commande manuelle pleine ; gauche/droite commandent son lacet, pas une translation.

Croisière : 100 ticks frais horizontaux (5 s), 60 verticaux (3 s), sans verrou ni protection ni réduction adaptative. Dérive latérale ≤0,5 m/s horizontale, ≤0,3 verticale ; variation de vitesse ≤max(0,25 m/s, 5 %), variation entre demi-fenêtres ≤0,1 m/s. Altitude horizontale ±1 bloc, vitesse verticale ≤0,15 m/s. Arrêt : vitesse totale ≤0,2 m/s et altitude ±1 bloc pendant 100 ticks. La durée exclut ces cinq secondes de confirmation. L’excursion horizontale et la perte d’altitude incluent toute la fenêtre de freinage ; pour une montée, la perte peut inclure un dépassement suivi d’un retour.

Les directions sont des vecteurs du monde relatifs au cap initial, sans garantie que le nez conserve ce cap. Ne pas interpréter les asymétries comme des limites aérodynamiques universelles. Les pics transitoires ne sont pas les vitesses retenues.

Le correctif 0.4.3 conserve le contrôle horizontal lors des commandes exclusivement verticales. Les sources exactes testées, graphes de départ, géométries, commandes et traces compressées sont joints par construction. Les mondes téléchargeables restent en 0.4.2 ; importer le nouveau contrôleur séparément.

Audit indépendant : 243 fenêtres stables relues dans les CSV ; 37/46 directions avec arrêt confirmé. ACK et facteur adaptatif sont vérifiés dans le Java du banc, mais ne sont pas présents dans les CSV. Les verrouillages et téléportations de réinitialisation sont exclus des fenêtres.

Les fichiers `speed-results.json` conservent aussi les paliers rejetés, les pics et les motifs d’échec. `summary.json` omet volontairement la vitesse si elle n’est pas prouvée.
