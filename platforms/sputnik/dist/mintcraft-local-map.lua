-- Declared geometry/local route view only. No world scan and no actuator writes.
local s=_G.MintCraftLocalMap
if not s then
 s={title=ui.label('Carte locale: geometrie declaree / trace et route; terrain inconnu'),view=ui.slider('1 dessus / 2 cote / 3 face / 4 perspective / 5 navigation',1,5,350),zoom=ui.slider('Zoom',.2,8,250),viewport=ui.viewport(440,280),status=ui.label('')}
 s.hull=ui.textfield(700);s.hull.setValue('');s.hullLabel=ui.label('Coque declaree facultative: x,y,z;... (256 points, pas de scan)')
 s.view.setValue(4);s.zoom.setValue(1);_G.MintCraftLocalMap=s
end
addElement(s.title);addElement(s.view);addElement(s.zoom);addElement(s.viewport);addElement(s.status);addElement(s.hullLabel);addElement(s.hull)
local geometry=input('Geometry','string');local route=input('Route','string');local position=input('Position','string');local trace=input('Trace','string')
local function points(text,limit)
 local out={};if type(text)~='string' or #text>20000 then return out end
 for line in text:gmatch('[^;\r\n]+') do local a,b,c=line:match('^([^,]+),([^,]+),([^,]+)');a,b,c=tonumber(a),tonumber(b),tonumber(c);if a and b and c and a==a and b==b and c==c and math.abs(a)<3e7 and math.abs(b)<3e7 and math.abs(c)<3e7 then out[#out+1]={a,b,c};if #out>=(limit or 64) then break end end end
 return out
end
local view=math.floor(s.view.getValue()+.5);s.viewport.clear();s.viewport.setZoom(s.zoom.getValue())
if view==1 or view==5 then s.viewport.setRotation(90,0,0) elseif view==2 then s.viewport.setRotation(0,90,0) elseif view==3 then s.viewport.setRotation(0,0,0) else s.viewport.setRotation(25,35,0) end
if view==5 then
 local origin=points(position)[1] or {0,0,0}
 for _,entry in ipairs({{route,'lime_wool'},{trace,'light_blue_wool'}}) do for _,p in ipairs(points(entry[1],256)) do s.viewport.addItem('minecraft',entry[2],p[1]-origin[1],p[2]-origin[2],p[3]-origin[3],0,0,0,.25) end end
 s.viewport.addItem('minecraft','yellow_wool',0,0,0,0,0,0,.6)
else
 for _,entry in ipairs({{geometry,'white_wool',.5},{s.hull.getValue(),'gray_wool',1}}) do for _,p in ipairs(points(entry[1],256)) do s.viewport.addItem('minecraft',entry[2],p[1],p[2],p[3],0,0,0,entry[3]) end end
end
s.status.setText('Position jaune, route verte, trace bleue; aucune preuve de degagement terrain')
