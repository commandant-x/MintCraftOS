-- Form inputs are authoritative: no empty import switch can mask them.
local groups={input('Group 1','string'),input('Group 2','string'),input('Group 3','string'),input('Group 4','string')}
local observations={input('Observation 1','string'),input('Observation 2','string'),input('Observation 3','string'),input('Observation 4','string')}
local a,b,oa,ob={},{},{},{};local used=0
for i=1,4 do
 local text=groups[i]
 if type(text)=='string' and text~='' then local list=i<=16 and a or b;list[#list+1]=#text<=2400 and not text:find('[^ -~]') and text or 'INVALID_GROUP';used=used+1 end
 local sample=observations[i]
 if type(sample)=='string' and #sample<=128 and sample~='' and not sample:find('\n',1,true) then local list=i<=16 and oa or ob;list[#list+1]=sample end
end
local s=_G.MintCraftSimpleGroups
if not s then s=ui.label('Activer et configurer les moteurs');_G.MintCraftSimpleGroups=s end
addElement(s);s.setText(used==0 and 'Aucun moteur: cocher Utiliser ce groupe dans les formulaires' or tostring(used)..' groupes recus depuis les formulaires; validation dans Pilotage')
local emit=output
if false then output('Groups A','string') output('Groups B','string') output('Observations A','string') output('Observations B','string') end
emit('Groups A',table.concat(a,'\n'));emit('Groups B',table.concat(b,'\n'));emit('Observations A',table.concat(oa,'\n'));emit('Observations B',table.concat(ob,'\n'))
