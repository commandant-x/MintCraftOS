-- Persistent native selector. This node never writes actuators.
local profiles={
 {name='Quad',layout='4 sustentations independantes; deplacement par inclinaison',ready=true},
 {name='Ballon',layout='Sustentation + propulsion/inverseur + 2 commandes gouverne'},
 {name='Venator',layout='2 groupes propulsion differentielle + 4 sustentations'},
 {name='Helicoptere',layout='Rotor principal + propulsion + commande de lacet'}
}
local s=_G.MintCraftArchitecture
if not s then
 s={selector=ui.slider('Architecture: 1 Quad / 2 Ballon / 3 Venator / 4 Helicoptere',1,4,360),
  name=ui.label('Architecture'),layout=ui.label(''),status=ui.label(''),
  help=ui.label('Enregistrer/fermer pour transmettre au serveur. Changement applique levier OFF.')}
 s.selector.setValue(1)
 _G.MintCraftArchitecture=s
end
addElement(s.selector) addElement(s.name) addElement(s.layout) addElement(s.status) addElement(s.help)
local value=s.selector.getValue()
local id=type(value)=='number' and value==value and value>=1 and value<=4 and math.floor(value+.5) or -1
local profile=profiles[id]
s.name.setText(profile and ('Choix: '..profile.name) or 'Selection invalide')
s.layout.setText(profile and profile.layout or '')
s.status.setText(profile and (profile.ready and 'Quad: stabilisation experimentale disponible' or 'Preparation uniquement: controleur de vol de ce profil non porte') or 'Rechoisir une architecture')
output('Architecture',id)
output('Flight backend available',profile and profile.ready and 1 or 0)
output('Selection',profile and profile.name or 'Invalide')
