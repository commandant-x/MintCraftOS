-- Pure bounded flight evidence. No actuator API, executable imports or hardware ACK.
local M={schema=1,maxFrames=1200,maxBytes=393216,maxEvents=64,pageBytes=44000}
local names={'tick','mass','ix','iy','iz','x','y','z','pitch','yaw','roll','vx','vy','vz','target','active','forward','left','vertical','residual','saturated','load','dimension','mode','revision','settings','scale'}
M.fields=names
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
M.finite=finite
local function split(s,sep) local r={};for v in (s..sep):gmatch('(.-)'..sep) do r[#r+1]=v end;return r end
local function clean(s) return tostring(s or ''):sub(1,300):gsub('[%z\1-\31,]',';') end
local function hash(s) local h=0;for i=1,#s do h=(h*33+s:byte(i))%2147483647 end;return h end
M.hash=hash
function M.decode(report)
 if type(report)~='string' or #report>12288 then return nil,'Rapport absent/trop long' end
 local header,line=report:match('^(MCREPORT1 [^\n]*)\n(MCF1,[^\n]+)')
 if not line then return nil,'Observation MCF1 absente' end
 local parts=split(line,',');if #parts~=#names+1 then return nil,'Champs MCF1 incomplets' end
 local f={reason=header:sub(13,524),groups={},line=line}
 for i,key in ipairs(names) do local v=parts[i+1];if key=='dimension' or key=='mode' or key=='settings' then f[key]=v else f[key]=v~='?' and tonumber(v) or nil;if v~='?' and not finite(f[key]) then return nil,'Valeur non finie '..key end end end
 for _,key in ipairs({'tick','mass','ix','iy','iz','x','y','z','pitch','yaw','roll','active','saturated'}) do if not finite(f[key]) then return nil,'Observation manquante '..key end end
 if f.tick<=0 or f.tick%1~=0 or f.mass<=0 or f.ix<=0 or f.iy<=0 or f.iz<=0 or (f.active~=0 and f.active~=1) or (f.saturated~=0 and f.saturated~=1) then return nil,'Contexte MCF1 invalide' end
 if math.max(math.abs(f.x),math.abs(f.y),math.abs(f.z))>30000000 then return nil,'Coordonnees invalides' end
 for _,key in ipairs({'forward','left','vertical'}) do if f[key] and (f[key]<-1 or f[key]>1) then return nil,'Commande hors domaine' end end
 if f.active==1 and not finite(f.target) then return nil,'Cible active absente' end
 local seen={}
 for group in report:gmatch('\nG,([^\n]+)') do
  local r=split(group,',');local id,level,rpm,fingerprint=tonumber(r[1]),tonumber(r[2]),tonumber(r[3]),tonumber(r[4])
  if #r~=4 or not finite(id) or id%1~=0 or id<1 or id>32 or seen[id] or #f.groups>=32 then return nil,'Groupe MCF1 invalide' end
  if r[2]~='?' and (not finite(level) or level%1~=0 or level<0 or level>15) then return nil,'Niveau emis invalide' end
  if r[3]~='?' and (not finite(rpm) or rpm<0 or rpm>100000) then return nil,'Etat estime invalide' end
  if not finite(fingerprint) or fingerprint<0 or fingerprint%1~=0 then return nil,'Empreinte absente' end
  seen[id]=true;f.groups[#f.groups+1]={id=id,level=level,rpm=rpm,hash=fingerprint}
 end
 f.raw=line..report:sub(#header+#line+2)
 return f
end
function M.context(f,settings,a,b)
 settings=f.settings
 if type(settings)~='string' or #settings>1024 or not settings:match('^MCU1;') then return nil,'Reglages non observes' end
 local all={};local fingerprints={}
 for _,text in ipairs({a,b}) do
  if type(text)~='string' or #text>38432 then return nil,'Montage trop long/absent' end
  for line in text:gmatch('[^\r\n]+') do
   local id=tonumber(line:match('^MCV1;(%d+);'));if not id or fingerprints[id] or #line>2400 or #all>=32 then return nil,'Descripteur montage invalide' end
   fingerprints[id]=hash(line);all[#all+1]=line
  end
 end
 for _,g in ipairs(f.groups) do if fingerprints[g.id]~=g.hash then return nil,'Brouillon different du montage actif' end end
 if #all~=#f.groups or #all==0 then return nil,'Montage actif incomplet' end
 return {settings=settings,groups=all,fingerprint=hash(settings..'\n'..table.concat(all,'\n'))}
end
-- Effective closed-loop correlation: a candidate, not mechanical identification.
function M.identify(history)
 local out={qualified=false,kind='closed-loop-correlation',samples=0,reason='Excitation independante insuffisante',groups={}}
 if #history<100 then return out end
 local first=history[1];local ids={}
 for _,g in ipairs(first.groups) do ids[#ids+1]=g.id end
 if #ids==0 then return out end
 local fraction={};local accelerations={};local independent={}
 for i,p in ipairs(history) do
  if math.abs(p.mass-first.mass)>first.mass*.01 or p.active~=1 or math.abs(p.pitch)>10 or math.abs(p.roll)>10 then out.reason='Masse/assiette variable: correlation rejetee';return out end
  if i>1 and p.tick~=history[i-1].tick+1 then out.reason='Cadence discontinue';return out end
  local u,sum={},0
  for _,g in ipairs(p.groups) do if not g.level then return out end;u[g.id]=g.level==0 and 1 or (15-g.level)/16;sum=sum+u[g.id] end
  if #p.groups~=#ids then return out end
  local mean=sum/#ids;fraction[i]=mean
  for _,id in ipairs(ids) do if not u[id] then return out end;independent[id]=(independent[id] or 0)+(u[id]-mean)^2 end
  if i>1 and p.vy and history[i-1].vy then accelerations[i]=(p.vy-history[i-1].vy)*20 end
 end
 local best
 for lag=0,10 do
  local n,sx,sy,sxx,syy,sxy=0,0,0,0,0,0
  for i=12,#history do local x,y=fraction[i-lag],accelerations[i];if x and y then n=n+1;sx=sx+x;sy=sy+y;sxx=sxx+x*x;syy=syy+y*y;sxy=sxy+x*y end end
  if n>=80 then
   local xx,yy,xy=sxx-sx*sx/n,syy-sy*sy/n,sxy-sx*sy/n
   if xx>1e-5 and yy>1e-5 and xy>0 then local correlation=xy/math.sqrt(xx*yy);if correlation>.55 and (not best or correlation>best.correlation) then best={lagTicks=lag,delaySeconds=lag/20,gain=xy/xx,correlation=correlation,samples=n} end end
  end
 end
 if best then out.collective=best;out.samples=best.samples;out.reason='Candidat collectif en boucle fermee; retest requis' end
 for _,id in ipairs(ids) do out.groups[#out.groups+1]={id=id,excitation=independent[id]/#history,identified=false,reason='Action simultanee des autres groupes non separee'} end
 return out
end
function M.policy()
 local s={factor=1,lastTick=nil,samples=0,trial=0,cooldown=0,lastSafe=1}
 function s:update(d,f,enabled)
  if not enabled or f.active==0 then self.factor=1;self.samples=0;self.baseline=nil;self.trial=0;return self.factor end
  if self.lastTick and f.tick<=self.lastTick then return self.factor end
  if self.lastTick and f.tick-self.lastTick>2 then self.samples=0;self.baseline=nil;self.trial=0 end
  self.lastTick=f.tick;self.samples=self.samples+1
  if self.cooldown>0 then self.cooldown=self.cooldown-1;return self.factor end
  if self.samples<20 then return self.factor end;self.samples=0
  local score=(d.heightSpan or 0)+(d.pitchSpan or 0)/10+(d.rollSpan or 0)/10
  if self.baseline then
   self.trial=self.trial+20
   if self.trial>=120 then
    if score>self.baseline*1.2+.2 then self.factor=self.previous;self.cooldown=120;self.event='Retour enveloppe precedente: oscillation accrue' end
    self.baseline=nil;self.trial=0
   end
  elseif d.oscillating and self.factor>.5 then
   self.previous=self.factor;self.baseline=score;self.trial=0;self.factor=math.max(.5,self.factor-.1);self.event='Enveloppe horizontale reduite apres oscillation observee'
  elseif d.ready and not d.oscillating and score<.5 then
   self.lastSafe=self.factor;self.factor=math.min(1,self.factor+.025)
  end
  return self.factor
 end
 return s
end
function M.new()
 local s={rows={},head=1,count=0,bytes=0,dropped=0,events={},sequence=0,epoch=0,history={},diagnosis='Attente observation serveur',freezeAt=nil,recording=true,stats={frames=0,gaps=0,duplicates=0,regressions=0},health={}}
 function s:event(tick,kind,text)
  self.events[#self.events+1]={tick=tick,kind=kind,text=clean(text)};if #self.events>M.maxEvents then table.remove(self.events,1) end
  if not self.firstFault and kind=='FAULT' then self.firstFault=clean(text) end
 end
 function s:freeze(why,limit)
  local rows={};local skip=math.max(0,self.count-(limit or self.count));for i=skip,self.count-1 do rows[#rows+1]=self.rows[(self.head+i-1)%M.maxFrames+1] end
  local events={};for _,e in ipairs(self.events) do events[#events+1]={tick=e.tick,kind=e.kind,text=e.text} end
  self.sequence=self.sequence+1;self.snapshot={rows=rows,context=self.context,events=events,epoch=self.epoch,sequence=self.sequence,dropped=self.dropped+skip,why=clean(why),source='writer-observations',rxAck=false};self.freezeAt=nil
 end
 function s:clear()
  self.rows={};self.head=1;self.count=0;self.bytes=0;self.dropped=0;self.events={};self.firstFault=nil;self.snapshot=nil;self.freezeAt=nil;self.history={};self.recording=true
 end
 function s:accept(f,now,context)
  if not finite(now) or now<=0 or f.tick>now or now-f.tick>2 then return false,'Observation serveur perimee/future' end
  if self.last and f.tick<=self.last.tick then
   local key=f.tick==self.last.tick and 'duplicates' or 'regressions';self.stats[key]=self.stats[key]+1
   if key=='regressions' then self:event(now,'FAULT','Horloge regresse: nouveau prevol requis');self.history={} end
   return false,key
  end
  local previous=self.last;local gap=previous and f.tick-previous.tick or 1
  if gap>1 then self.stats.gaps=self.stats.gaps+1;self.history={};self:event(f.tick,'GAP','Observations manquantes: '..gap) end
  if f.active==1 and (not previous or previous.active~=1) then
   if self.count>0 then self:freeze('Vol precedent') end
   self.rows={};self.head=1;self.count=0;self.bytes=0;self.dropped=0;self.history={};self.events={};self.firstFault=nil;self.epoch=self.epoch+1;self.context=context;self.recording=true
   self:event(f.tick,'ARM','Nouveau vol; contexte '..(context and 'declare concordant' or 'non verifie'))
  end
  if previous and f.active~=previous.active then self:event(f.tick,'MODE',f.active==1 and 'Actif' or 'Desarme') end
  if previous and math.abs(f.mass-previous.mass)>math.max(.01,previous.mass*.005) then self:event(f.tick,'MASS','Masse exposee '..previous.mass..' -> '..f.mass) end
  if f.reason:find('FIRST=',1,true) and not self.firstFault then self:event(f.tick,'FAULT',f.reason);self.freezeAt=f.tick+40 end
  self.stats.frames=self.stats.frames+1;self.last=f
  self.history[#self.history+1]=f;while #self.history>120 do table.remove(self.history,1) end
  if not self.recording then return true end
  local row=f.raw;local length=#row
  while self.count>0 and (self.count>=M.maxFrames or self.bytes+length>M.maxBytes) do
   local old=self.rows[self.head];self.bytes=self.bytes-#old;self.rows[self.head]=nil;self.head=self.head%M.maxFrames+1;self.count=self.count-1;self.dropped=self.dropped+1
  end
  if length<=M.maxBytes then local index=(self.head+self.count-1)%M.maxFrames+1;self.rows[index]=row;self.count=self.count+1;self.bytes=self.bytes+length end
  if self.freezeAt and f.tick>=self.freezeAt then self:freeze('Premier defaut + 2 s observees') end
  return true
 end
 function s:diagnose(now)
  local f=self.last;if not f or not finite(now) or now<f.tick or now-f.tick>2 then return {summary='Attente observation serveur',ready=false,protect=false} end
  local result={ready=false,protect=false,summary='Collecte: 120 observations requises',confidence='incomplete',response={},saturation=0}
  if f.active==0 then result.summary='Desarme; aucun vol qualifie';return result end
  local h=self.history;if #h<120 or h[#h].tick~=f.tick or h[#h].tick-h[1].tick>121 then return result end
  local heightMin,heightMax=math.huge,-math.huge;local pitchMin,pitchMax=math.huge,-math.huge;local rollMin,rollMax=math.huge,-math.huge
  local turnsY,turnsP,turnsR=0,0,0;local signY,signP,signR=0,0,0;local quiet=true;local saturated=0;local vertical2,horizontal2=0,0;local velocities=true
  local function changed(delta,old,threshold) local sign=delta>threshold and 1 or delta< -threshold and -1 or old;return sign,old~=0 and sign~=old and 1 or 0 end
  for i,p in ipairs(h) do
   if not p.target then return result end
   local error=p.y-p.target;heightMin=math.min(heightMin,error);heightMax=math.max(heightMax,error);pitchMin=math.min(pitchMin,p.pitch);pitchMax=math.max(pitchMax,p.pitch);rollMin=math.min(rollMin,p.roll);rollMax=math.max(rollMax,p.roll)
   quiet=quiet and (p.reason:match('^HOLDING') or p.reason:match('^DEGRADED')) and p.revision==h[1].revision and p.forward==0 and p.left==0 and p.vertical==0 and p.active==1 and math.abs(p.target-h[1].target)<.05
   saturated=saturated+p.saturated
   if p.vx and p.vy and p.vz then vertical2=vertical2+p.vy^2;horizontal2=horizontal2+p.vx^2+p.vz^2 else velocities=false end
   if i>1 then local old=h[i-1];local n;signY,n=changed(p.y-old.y,signY,.004);turnsY=turnsY+n;signP,n=changed(p.pitch-old.pitch,signP,.04);turnsP=turnsP+n;signR,n=changed(p.roll-old.roll,signR,.04);turnsR=turnsR+n end
  end
  local a,b=h[#h-19],h[#h];local fresh=true;local stable=true
  for i=#h-19,#h do local p=h[i];fresh=fresh and (i==#h-19 or p.tick==h[i-1].tick+1);stable=stable and math.abs(p.target-h[#h-19].target)<=.05 and p.vx~=nil and p.vy~=nil and p.vz~=nil and p.vx^2+p.vz^2<=.04 and p.forward==0 and p.left==0 and p.vertical==0 and math.abs(p.vy)<=.1 and math.abs(p.y-p.target)<=1 and math.abs(p.pitch)<=5 and math.abs(p.roll)<=5 end
  result.ready=fresh and stable;result.confidence=velocities and 'observations fraiches' or 'vitesses manquantes';result.heightSpan=heightMax-heightMin;result.pitchSpan=pitchMax-pitchMin;result.rollSpan=rollMax-rollMin;result.verticalRms=velocities and math.sqrt(vertical2/#h) or nil;result.horizontalRms=velocities and math.sqrt(horizontal2/#h) or nil;result.saturation=saturated/#h
  result.oscillating=quiet and not f.reason:find('CALIBRATING',1,true) and not f.reason:find('RECOVERING',1,true) and ((turnsY>=4 and result.heightSpan>.6) or (turnsP>=4 and result.pitchSpan>4) or (turnsR>=4 and result.rollSpan>4))
  result.protect=result.oscillating and (result.heightSpan>2 or result.pitchSpan>12 or result.rollSpan>12)
  result.summary=result.oscillating and 'Oscillation persistante observee' or result.saturation>.5 and 'Allocation frequemment saturee' or result.ready and 'Maintien observe: 20 mesures fraiches; non certifie' or 'Mouvement/transitoire observe'
  -- Passive correlation is a candidate, never observed shaft response or a cause proof.
  local braking={};for i=2,#h do local p,old=h[i],h[i-1];if p.vx and p.vz and old.vx and old.vz and p.forward==0 and p.left==0 then local before=math.sqrt(old.vx^2+old.vz^2);local after=math.sqrt(p.vx^2+p.vz^2);if before>.5 and after<before then braking[#braking+1]=(before-after)*20/(p.tick-old.tick) end end end
  if #braking>=20 then table.sort(braking);result.braking=braking[math.floor(#braking/2)+1];result.brakingSamples=#braking end
  return result
 end
 function s:pages()
  local snap=self.snapshot;if not snap then return {},'Figer un instantane serveur' end
  local lines={}
  if snap.context then lines[#lines+1]='S,'..snap.context.settings;for _,g in ipairs(snap.context.groups) do lines[#lines+1]='C,'..g end end
  for _,e in ipairs(snap.events) do lines[#lines+1]='E,'..e.tick..','..e.kind..','..e.text end
  for _,r in ipairs(snap.rows) do for line in r:gmatch('[^\n]+') do lines[#lines+1]=line end end
  local chunks,part,bytes={},{},0
  for _,line in ipairs(lines) do
   if bytes+#line+1>M.pageBytes and #part>0 then chunks[#chunks+1]=table.concat(part,'\n');part={};bytes=0 end
   part[#part+1]=line;bytes=bytes+#line+1
  end
  if #part>0 then chunks[#chunks+1]=table.concat(part,'\n') end
  local pages={};local totalHash=hash(table.concat(chunks,'\n'))
  for i,chunk in ipairs(chunks) do pages[i]=table.concat({'MCLOG1',snap.epoch,snap.sequence,i,#chunks,#snap.rows,snap.dropped,totalHash,snap.context and snap.context.fingerprint or 0},';')..'\n'..chunk end
  return pages
 end
 return s
end
return M
