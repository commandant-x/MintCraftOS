-- Bounded configuration transport only. No hardware IO.
local groups={input('Group 1','string'),input('Group 2','string'),input('Group 3','string'),input('Group 4','string'),input('Group 5','string'),input('Group 6','string'),input('Group 7','string'),input('Group 8','string'),input('Group 9','string'),input('Group 10','string'),input('Group 11','string'),input('Group 12','string'),input('Group 13','string'),input('Group 14','string'),input('Group 15','string'),input('Group 16','string'),input('Group 17','string'),input('Group 18','string'),input('Group 19','string'),input('Group 20','string'),input('Group 21','string'),input('Group 22','string'),input('Group 23','string'),input('Group 24','string'),input('Group 25','string'),input('Group 26','string'),input('Group 27','string'),input('Group 28','string'),input('Group 29','string'),input('Group 30','string'),input('Group 31','string'),input('Group 32','string')}
local a,b={},{}
for i=1,32 do local text=groups[i];if type(text)=='string' and text~='' then local list=i<=16 and a or b;list[#list+1]=#text<=2400 and not text:find('[^ -~]') and text or 'INVALID_GROUP' end end
local s=_G.MintCraftMountBus
if not s then
 s={title=ui.label('Montage global: exporter/importer les groupes. Les changements en vol restent en attente OFF.'),use=ui.checkbox('Utiliser les descripteurs importes (au lieu des formulaires)'),capture=ui.button('Exporter les formulaires vers les deux champs',360),a=ui.textfield(700),b=ui.textfield(700)}
 s.a.setValue('');s.b.setValue('');_G.MintCraftMountBus=s
end
addElement(s.title);addElement(s.use);addElement(s.capture);addElement(s.a);addElement(s.b)
if s.capture.wasClicked() then s.a.setValue(table.concat(a,'\n'));s.b.setValue(table.concat(b,'\n')) end
if s.use.isChecked() then
 local function imported(value)
  if type(value)~='string' or #value>38432 or value:find('[^ -~\r\n]') then return {'INVALID_IMPORT'} end
  local out={};for line in value:gmatch('[^\r\n]+') do out[#out+1]=line;if #line>2400 or #out>16 then return {'INVALID_IMPORT'} end end;return out
 end
 a,b=imported(s.a.getValue()),imported(s.b.getValue())
end
local emit=output
if false then output('Groups A','string') output('Groups B','string') end
emit('Groups A',table.concat(a,'\n'));emit('Groups B',table.concat(b,'\n'))

local observations={input('Observation 1','string'),input('Observation 2','string'),input('Observation 3','string'),input('Observation 4','string'),input('Observation 5','string'),input('Observation 6','string'),input('Observation 7','string'),input('Observation 8','string'),input('Observation 9','string'),input('Observation 10','string'),input('Observation 11','string'),input('Observation 12','string'),input('Observation 13','string'),input('Observation 14','string'),input('Observation 15','string'),input('Observation 16','string'),input('Observation 17','string'),input('Observation 18','string'),input('Observation 19','string'),input('Observation 20','string'),input('Observation 21','string'),input('Observation 22','string'),input('Observation 23','string'),input('Observation 24','string'),input('Observation 25','string'),input('Observation 26','string'),input('Observation 27','string'),input('Observation 28','string'),input('Observation 29','string'),input('Observation 30','string'),input('Observation 31','string'),input('Observation 32','string')}
local a,b={},{}
for i=1,32 do local text=observations[i];if type(text)=='string' and #text<=128 and text~='' and not text:find('\n',1,true) then local list=i<=16 and a or b;list[#list+1]=text end end
if false then output('Observations A','string') output('Observations B','string') end
emit('Observations A',table.concat(a,'\n'));emit('Observations B',table.concat(b,'\n'))
