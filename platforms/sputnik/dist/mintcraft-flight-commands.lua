-- Client buttons commit persistent request fields. Server decides and acknowledges.
local modes={'HOLD','ALTITUDE','HEADING','ROUTE','PAUSE','RESUME','CANCEL','RETURN','CALIBRATE','CAL_PAUSE','CAL_RESUME','MANUAL','CAL_ABORT'}
local s=_G.MintCraftCommands
if not s then
 s={title=ui.label('Pilotage / Navigation: appliquer puis sauvegarder-fermer'),mode=ui.slider('Mode 1 maintien 2 altitude 3 vitesse-cap 4 route 5 pause 6 reprise 7 annule 8 retour 9 essais 10/11 pause/reprise essais 12 manuel 13 abandon essais',1,13,460),apply=ui.button('Appliquer consignes',240),fields={},quick={},status=ui.label('Attente'),packet=ui.textfield(500),revision=ui.textfield(100)}
 for _,entry in ipairs({{'HOLD','Maintenir ici'},{'ALTITUDE','Tenir cette altitude'},{'HEADING','Suivre vitesse et cap'},{'CALIBRATE','Tester le montage'},{'PAUSE','Pause mission'},{'RESUME','Reprendre mission'},{'CAL_PAUSE','Pause essais'},{'CAL_RESUME','Reprendre essais'},{'RETURN','Retour depart'},{'CANCEL','Annuler mission'},{'MANUAL','Reprise clavier'},{'CAL_ABORT','Abandonner essais'}}) do s.quick[#s.quick+1]={mode=entry[1],button=ui.button(entry[2],240)} end
 s.stop=ui.checkbox('Arret horizontal (maintien vertical); decocher puis appliquer pour repartir');s.cut=ui.checkbox('Coupure mecanique: perte de sustentation; OFF physique requis ensuite');s.stop.setChecked(false);s.cut.setChecked(false)
 s.expert=ui.label('Navigation et commandes avancees ci-dessous')
 s.mode.setValue(1);s.revision.setValue('0');s.packet.setValue('')
 for _,entry in ipairs({{'altitude','Altitude demandee m','80'},{'speed','Vitesse demandee m/s (0 libre/auto)','0'},{'heading','Cap trajectoire deg +Z=0','0'},{'route','Route x,y,z[,vitesse];...',''},{'zones','Zones xmin,ymin,zmin,xmax,ymax,zmax;...',''}}) do local f={label=ui.label(entry[2]),value=ui.textfield(440)};f.value.setValue(entry[3]);s.fields[entry[1]]=f end
 s.step=ui.slider('Distance des points relatifs (blocs)',1,100,240);s.step.setValue(10);s.offsets={}
 for _,entry in ipairs({{'Point +X',1,0,0},{'Point -X',-1,0,0},{'Point +Y',0,1,0},{'Point -Y',0,-1,0},{'Point +Z',0,0,1},{'Point -Z',0,0,-1}}) do s.offsets[#s.offsets+1]={button=ui.button(entry[1],160),x=entry[2],y=entry[3],z=entry[4]} end
 s.follow=ui.button('Suivre le point selectionne',240);s.nameIndex=ui.slider('Route nommee selectionnee',1,16,240);s.nameIndex.setValue(1)
 s.point=ui.slider('Point selectionne',1,64,220);s.point.setValue(1)
 s.current=ui.button('Ajouter position actuelle',240);s.remove=ui.button('Retirer point selectionne',240);s.edit=ui.button('Charger point selectionne',240);s.replace=ui.button('Remplacer point selectionne',240)
 s.pointText=ui.textfield(440);s.pointText.setValue('');s.add=ui.button('Ajouter point x,y,z,vitesse',240)
 s.library=ui.textfield(600);s.library.setValue('MCR1');s.name=ui.textfield(220);s.name.setValue('route-1');s.save=ui.button('Enregistrer route nommee',240);s.restore=ui.button('Charger route nommee',240);s.names=ui.label('Routes: aucune')
 s.help=ui.label('Terrain non observe. Pause/STOP horizontal conserve sustentation. Levier physique OFF distinct de la coupure mecanique.');_G.MintCraftCommands=s
end
addElement(s.title)
for _,key in ipairs({'altitude','speed','heading'}) do local f=s.fields[key];addElement(f.label);addElement(f.value) end
for _,entry in ipairs(s.quick) do addElement(entry.button) end
addElement(s.status);addElement(s.stop);addElement(s.cut);addElement(s.expert);addElement(s.mode)
for _,key in ipairs({'route','zones'}) do local f=s.fields[key];addElement(f.label);addElement(f.value) end
for _,key in ipairs({'point','current','remove','edit','replace','pointText','add','name','save','restore','names','library'}) do addElement(s[key]) end
addElement(s.step);for _,entry in ipairs(s.offsets) do addElement(entry.button) end;addElement(s.follow);addElement(s.nameIndex)
addElement(s.apply);addElement(s.revision);addElement(s.packet);addElement(s.status);addElement(s.help)
local function split(text,pattern,limit) local out={};if type(text)=='string' and #text<=24000 then for value in text:gmatch(pattern) do out[#out+1]=value;if #out>=limit then break end end end;return out end
local currentPosition=input('Position','string')
local points=split(s.fields.route.value.getValue(),'[^;\r\n]+',64)
local index=math.max(1,math.min(#points,math.floor(s.point.getValue()+.5)))
local selected=s.fields.route.value
if s.current.wasClicked() and #points<64 then
 local position=currentPosition;if type(position)=='string' and position:match('^[%d%+%-%.eE]+,[%d%+%-%.eE]+,[%d%+%-%.eE]+$') then points[#points+1]=position..','..s.fields.speed.value.getValue();selected.setValue(table.concat(points,';')) end
end
for _,entry in ipairs(s.offsets) do
 if entry.button.wasClicked() and #points<64 then
  local position=currentPosition;local x,y,z
  if type(position)=='string' then x,y,z=position:match('^([^,]+),([^,]+),([^,]+)$') end
  x,y,z=tonumber(x),tonumber(y),tonumber(z)
  if x and y and z and x==x and y==y and z==z then local step=s.step.getValue();points[#points+1]=table.concat({x+entry.x*step,y+entry.y*step,z+entry.z*step,s.fields.speed.value.getValue()},',');selected.setValue(table.concat(points,';')) end
 end
end
if s.remove.wasClicked() and points[index] then table.remove(points,index);selected.setValue(table.concat(points,';')) end
if s.edit.wasClicked() and points[index] then s.pointText.setValue(points[index]) end
if s.replace.wasClicked() and points[index] and #s.pointText.getValue()<=240 then points[index]=s.pointText.getValue();selected.setValue(table.concat(points,';')) end
if s.add.wasClicked() and #points<64 and #s.pointText.getValue()<=240 then points[#points+1]=s.pointText.getValue();selected.setValue(table.concat(points,';')) end
local records=split(s.library.getValue(),'[^\r\n]+',17);local routes,names={},{}
if records[1]=='MCR1' then for i=2,#records do local name,route=records[i]:match('^([%w_%-]+)|(.*)$');if name and #name<=32 and #route<=12000 then routes[name]=route;names[#names+1]=name end end end
local picked=math.max(1,math.min(16,math.floor(s.nameIndex.getValue()+.5)))
if picked~=s.nameIndexSeen and names[picked] then s.name.setValue(names[picked]) end;s.nameIndexSeen=picked
local name=s.name.getValue()
if s.restore.wasClicked() and routes[name] then selected.setValue(routes[name]) end
if s.save.wasClicked() and name:match('^[%w_%-]+$') and #name<=32 and (routes[name] or #names<16) and #selected.getValue()<=12000 then
 routes[name]=selected.getValue();names={};for key in pairs(routes) do names[#names+1]=key end;table.sort(names)
 local text={'MCR1'};for _,key in ipairs(names) do text[#text+1]=key..'|'..routes[key] end
 local value=table.concat(text,'\n');if #value<=24000 then s.library.setValue(value) end
end
s.names.setText('Point '..index..'/'..#points..' = '..tostring(points[index] or 'aucun')..' | Routes: '..table.concat(names,', '))
local acknowledged=input('Acknowledged revision')
local chosen,singlePoint
if s.follow.wasClicked() and points[index] then chosen='ROUTE';singlePoint=points[index] end
for _,entry in ipairs(s.quick) do if entry.button.wasClicked() then chosen=entry.mode end end
if s.apply.wasClicked() or chosen then
 local seq=math.max(tonumber(s.revision.getValue()) or 0,type(acknowledged)=='number' and acknowledged or 0)+1
 local values={'MCC1',tostring(seq),chosen or modes[math.max(1,math.min(13,math.floor(s.mode.getValue()+.5)))]}
 for _,key in ipairs({'altitude','speed','heading','route','zones'}) do values[#values+1]=key=='route' and singlePoint or s.fields[key].value.getValue() end
 s.packet.setValue(table.concat(values,'|'));s.revision.setValue(tostring(seq))
end
s.status.setText('Revision acceptee serveur: '..tostring(acknowledged)..' | '..tostring(input('Status','string'))..' | '..tostring(input('Diagnosis','string')))
local emit=output
if false then output('Request','string') output('Stop requested',0) output('Cut requested',0) end
emit('Request',s.packet.getValue())

emit('Stop requested',s.stop.isChecked() and 1 or 0);emit('Cut requested',s.cut.isChecked() and 1 or 0)
