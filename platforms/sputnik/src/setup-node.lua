-- Montage settings are separate from live consignes; no actuator writes.
local s=_G.MintCraftSetup
if not s then
 s={title=ui.label('Montage commun: 1 Quad / 2 Ballon / 3 Venator / 4 Helicoptere / 5 Hybride'),profile=ui.slider('Architecture',1,5,300),confirmed=ui.checkbox('Montage, sens, repli et reprise physique verifies'),zone=ui.checkbox('Zone essai degagee verifiee (pas de scanner terrain)'),released=ui.checkbox('Anciens recepteurs retires avant changement de frequences'),steering=ui.checkbox('Q/D: virage de trajectoire (decocher: lateral sur quad)'),fields={}}
 s.profile.setValue(1);s.steering.setChecked(true)
 for _,entry in ipairs({{'gravity','Gravite serveur','11'},{'climb','Consigne montee m/s','1'},{'tilt','Inclinaison deplacement: 0 < deg <= 20','8'},{'margin','Rayon englobant coque + pales + marge m (requis)',''},{'braking','Deceleration de planification estimee m/s2','1'}}) do
  local f={label=ui.label(entry[2]),value=ui.textfield(160)};f.value.setValue(entry[3]);s.fields[entry[1]]=f
 end
 s.help=ui.label('Le pilote continue serveur apres fermeture. Configuration en vol: en attente OFF. Aucun ACK Link suppose.');_G.MintCraftSetup=s
end
addElement(s.title);addElement(s.profile);addElement(s.confirmed);addElement(s.zone);addElement(s.released);addElement(s.steering)
local values={'MCU1',tostring(math.floor(s.profile.getValue()+.5))}
for _,key in ipairs({'gravity','climb','tilt','margin','braking'}) do local f=s.fields[key];addElement(f.label);addElement(f.value);values[#values+1]=f.value.getValue() end
local why
for _,rule in ipairs({{'gravity',0,100,'Gravite: 0 < valeur <= 100'},{'climb',0,5,'Montee: 0 < valeur <= 5 m/s'},{'tilt',0,20,'Inclinaison: 0 < valeur <= 20 deg'},{'margin',0,math.huge,'Rayon coque + pales: nombre positif requis'},{'braking',0,math.huge,'Freinage: deceleration positive requise'}}) do
 local v=tonumber(s.fields[rule[1]].value.getValue())
 if not v or v~=v or (rule[1]=='margin' and v<0 or rule[1]~='margin' and v<=rule[2]) or v>rule[3] or v==math.huge then why=rule[4];break end
end
s.help.setText(why or 'Reglages locaux valides. Confirmer le montage, sauvegarder puis OFF/ON. Le pilote continue serveur apres fermeture.')
addElement(s.help)
values[#values+1]=s.confirmed.isChecked() and '1' or '0';values[#values+1]=s.zone.isChecked() and '1' or '0';values[#values+1]=s.released.isChecked() and '1' or '0';values[#values+1]=s.steering.isChecked() and '1' or '0'
local emit=output
if false then output('Settings','string') output('Architecture',0) end
emit('Settings',table.concat(values,';'));emit('Architecture',math.floor(s.profile.getValue()+.5))
