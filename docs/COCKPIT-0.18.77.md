# Pilotage direct — 0.18.77

Dans Navigation > Flight, ouvrir **Control**. Les valeurs sont des consignes,
pas des paramètres du câblage : les modifier ne demande pas de sauvegarder la
configuration des moteurs.

1. Cliquer **Preparation automatique**, puis confirmer que la zone est dégagée.
   Les montées/descentes mesurent la réponse du vaisseau. Attendre la fin des
   essais et le maintien actif, puis revenir dans Flight > Control.
2. Choisir une **altitude monde** dans la plage mesurée. Si deux groupes moteurs
   indépendants ont été mesurés et validés, choisir aussi la **vitesse en m/s**
   et le **cap en degrés** (+Z = 0°, +X = 90°).
3. Cliquer **Appliquer les consignes**. Cette action remplace une route en cours
   par le maintien direct de l'altitude, de la vitesse et du cap demandés.
   Une consigne refusée laisse les consignes précédentes intactes.
4. **STOP / F10** applique le secours et désengage les moteurs. Fermer la fenêtre,
   perdre le retour des actionneurs ou perdre les permissions arrête aussi le vol.

Un appareil sans autorité horizontale vérifiée propose uniquement l'altitude.
La vitesse maximale affichée vient des essais moteurs ; la table d'altitude
n'est pas extrapolée. L'interface montre les mesures et les consignes réellement
appliquées. La précision réelle dépend du montage et des mesures Minecraft ;
les essais automatisés utilisent un modèle simulé, pas un serveur Minecraft.

Depuis 0.18.78, les valeurs de **Options** sont également lues par
**Preparation automatique / Activate autopilot** : notamment le premier et le
dernier niveau de chauffe. La confirmation affiche cette plage et fige les
valeurs. Modifier la plage demande une nouvelle mesure, même si une table est
sauvegardée. Une calibration déjà active doit être arrêtée avec STOP avant de
changer ses options ; les consignes de vol se changent dans Control.

Pour le pilote complet, activer les trois options d'initialisation, maintien
et certification. Si vous souhaitez seulement mesurer sans ces étapes,
utiliser **Start sequence** ; le pilote complet refuse explicitement les options
incompatibles plutôt que de les remplacer en silence.
