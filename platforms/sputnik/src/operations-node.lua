-- Observer/supervisor. Never owns a Redstone Link; controller keeps all actuation.
local s=_G.MintCraftOperations
if not s then
 s={journal=Journal.new(),policy=Journal.policy(),title=ui.label('Vol / diagnostic / export serveur'),status=ui.label('Attente serveur'),protect=ui.checkbox('Protection: adaptation enveloppe puis pause horizontale si severe'),page=ui.slider('Page export a copier (44 Ko maximum)',1,32,300),export=ui.textfield(540),control=ui.textfield(180),seq=ui.textfield(100),request=ui.textfield(180),freeze=ui.button('Figer rapport court (120 observations)',300),full=ui.button('Figer historique complet',300),resume=ui.button('Reprendre enregistrement',300),clear=ui.button('Effacer le journal (aucun moteur)',300),reset=ui.button('Acquitter la protection horizontale',300),view=ui.slider('1 diagnostic / 2 carte dessus / 3 montage actif / 4 brouillon',1,4,320),viewport=ui.viewport(400,220),hull=ui.textfield(440),label=ui.label('Coque declaree: x,y,z;... (pas de scan)'),summary=ui.label(''),pageSeen=0,guard=false}
 s.protect.setChecked(true);s.page.setValue(1);s.seq.setValue('0');s.request.setValue('');s.export.setValue('');s.control.setValue('');s.view.setValue(1);s.hull.setValue('');_G.MintCraftOperations=s
end
for _,key in ipairs({'title','status','protect','freeze','full','resume','clear','reset','summary','view','viewport','label','hull','page','export','seq','request','control'}) do addElement(s[key]) end
local function read(name) if type(_G[name])=='function' then local ok,v=pcall(_G[name]);if ok then return v end end end
local now=read('getUniverseTime');local nativeMass=read('getShipMass');local server=JournalFinite(now) and now>0 and JournalFinite(nativeMass) and nativeMass>0
local report=input('Flight report','string');local settings=input('Settings','string');local groupsA=input('Groups A','string');local groupsB=input('Groups B','string')
local f,why=Journal.decode(report)
local request=s.request.getValue()
local actions={{s.freeze,'FREEZE'},{s.full,'FULL'},{s.resume,'RESUME'},{s.clear,'CLEAR'},{s.reset,'ACK'}}
for _,entry in ipairs(actions) do
 if entry[1].wasClicked() then local revision=math.max(tonumber(s.seq.getValue()) or 0,tonumber(s.control.getValue():match('ACK=(%d+)')) or 0)+1;if revision<2147483647 then s.seq.setValue(tostring(revision));s.request.setValue('MCREC1;'..revision..';'..entry[2]);request=s.request.getValue() end end
end
if server then
 if s.seen==nil then s.seen=request end
 if request~=s.seen then
  local revision,action=request:match('^MCREC1;(%d+);([A-Z]+)$');revision=tonumber(revision)
  if revision and revision>(s.revision or 0) and revision<2147483647 then
   s.revision=revision
   if action=='FREEZE' then s.journal:freeze('Demande operateur',120);s.journal.recording=false
   elseif action=='FULL' then s.journal:freeze('Historique complet');s.journal.recording=false
   elseif action=='RESUME' then s.journal.recording=true
   elseif action=='CLEAR' then s.journal:clear();s.pages=nil;s.snapshotSeen=nil;s.pageSeen=0
   elseif action=='ACK' then if not s.protect.isChecked() or s.diagnostic and s.diagnostic.ready and not s.diagnostic.protect then s.guard=false else s.journal:event(now,'ACK_REFUSED','20 mesures stables requises, ou desactiver explicitement la protection') end end
  end
  s.seen=request
 end
 local accepted=false
 if f then
  local context=Journal.context(f,settings,groupsA,groupsB)
  accepted,why=s.journal:accept(f,now,context)
 elseif type(report)=='string' and report:find('FIRST=',1,true) and not s.journal.firstFault then
  s.journal:event(now,'FAULT',report:match('^[^\n]+') or 'Rapport invalide');s.journal:freeze('Defaut sans pose valide')
 end
 local diagnosed=not s.diagnosticAt or now-s.diagnosticAt>=5
 if diagnosed then s.diagnostic=s.journal:diagnose(now);s.diagnosticAt=now end
 if not s.modelAt or now-s.modelAt>=20 then s.model=Journal.identify(s.journal.history);s.modelAt=now end
 if accepted and diagnosed and #s.journal.history>=120 and s.diagnostic.protect and s.protect.isChecked() then
  if not s.guard then s.journal:event(now,'PROTECT','Pause horizontale: oscillation severe observee');s.journal.freezeAt=now+40 end
  s.guard=true
 end
 if accepted then
  if s.epoch~=s.journal.epoch then s.policy=Journal.policy();s.epoch=s.journal.epoch end
  s.policy:update(s.diagnostic,f,s.protect.isChecked())
  if s.policy.event then s.journal:event(now,'ADAPT',s.policy.event);s.policy.event=nil end
 end
 if accepted and f.active==0 then s.guard=false end
 local snapshot=s.journal.snapshot
 local page=math.max(1,math.min(32,math.floor(s.page.getValue()+.5)))
 if snapshot and (snapshot.sequence~=s.snapshotSeen or s.pageSeen~=page) then s.pages=s.journal:pages();s.snapshotSeen=snapshot.sequence;s.pageSeen=page end
 local value=s.pages and s.pages[page] or ''
 -- Reassert authoritative text: stale editor cache never becomes flight evidence.
 s.export.setValue(value)
 s.control.setValue('ACK='..tostring(s.revision or 0)..' pages='..tostring(s.pages and #s.pages or 0)..' sequence='..tostring(snapshot and snapshot.sequence or 0))
 local d=s.diagnostic
 local text=d.summary..' | m='..tostring(f and f.mass or '?')..' | journal='..s.journal.count..' pertes='..s.journal.stats.gaps..' | '..(s.guard and 'PAUSE HORIZONTALE ACTIVE' or 'sustentation independante')
 s.status.setText(text)
 s.summary.setText('Hauteur pic-pic='..tostring(d.heightSpan or '?')..' | Pitch='..tostring(d.pitchSpan or '?')..' Roll='..tostring(d.rollSpan or '?')..' | saturation='..tostring(d.saturation or '?')..' | freinage candidat='..tostring(d.braking or '?')..' | enveloppe='..tostring(s.policy.factor)..' | delai candidat='..tostring(s.model and s.model.collective and s.model.collective.delaySeconds or '?')..' | FIRST='..tostring(s.journal.firstFault or 'aucun'))
 if type(display)=='function' then pcall(display,'MC_FLIGHT_DIAG',text);pcall(display,'MC_FLIGHT_EXPORT',value) end
else s.status.setText('Client: lire MC_FLIGHT_DIAG; figer puis sauvegarder/fermer et rouvrir pour copier les pages serveur') end
-- Rendering is independent from server sampling and is bounded to declared data.
local view=math.floor(s.view.getValue()+.5)
local draftGeometry=input('Draft geometry','string')
if not server then
 local text=(view==4 and draftGeometry or view==2 and input('Route','string') or input('Geometry','string')) or ''
 local position=input('Position','string');local ox,oy,oz=0,0,0
 if view==2 and type(position)=='string' then ox,oy,oz=position:match('^([^,]+),([^,]+),([^,]+)');ox,oy,oz=tonumber(ox) or 0,tonumber(oy) or 0,tonumber(oz) or 0 end
 local key=tostring(view)..text..s.hull.getValue()..tostring(position)
 if key~=s.renderSeen then
  s.renderSeen=key;s.viewport.clear();s.viewport.setZoom(1);s.viewport.setRotation(view==2 and 90 or 25,view==2 and 0 or 35,0)
  if view==2 then s.viewport.addItem('minecraft','yellow_wool',0,0,0,0,0,0,.6) end
  if view~=1 then
   for _,entry in ipairs({{text,'lime_wool'},{view==2 and input('Trace','string') or s.hull.getValue(),'gray_wool'}}) do
    local count=0
    if type(entry[1])=='string' and #entry[1]<=20000 then for line in entry[1]:gmatch('[^;\r\n]+') do
     local x,y,z=line:match('^([^,]+),([^,]+),([^,]+)');x,y,z=tonumber(x),tonumber(y),tonumber(z)
     if JournalFinite(x) and JournalFinite(y) and JournalFinite(z) and math.max(math.abs(x),math.abs(y),math.abs(z))<=30000000 then s.viewport.addItem('minecraft',entry[2],x-ox,y-oy,z-oz,0,0,0,.4);count=count+1;if count>=128 then break end end
    end end
   end
  end
 end
end
local emit=output
if false then output('Stop horizontal',0) output('Mechanical cut',0) output('Stability request','string') output('Diagnosis','string') output('Export page','string') end
emit('Stop horizontal',server and (s.guard or input('Stop requested')==1) and 1 or 0)
-- Cut is an explicit separate operator request, never inferred from oscillation.
emit('Mechanical cut',server and input('Cut requested')==1 and 1 or 0)
emit('Diagnosis',server and s.diagnostic and s.diagnostic.summary or 'Client: voir serveur')
emit('Export page',server and s.export.getValue() or '')

emit('Stability request',server and f and f.tick<=now and now-f.tick<=2 and 'MCSUP1,'..f.tick..','..s.policy.factor or '')
