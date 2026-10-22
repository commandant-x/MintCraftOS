local addon=require("system.libraries.addon")
local forms=require("system.gui.form")
local ui=require("system.gui.components")
local renderer=require("system.gui.renderer")
local M={}

function M.coordinates(text,kind)
  local values={}
  for token in tostring(text):gmatch("[^,%s;()]+") do
    local value=tonumber(token)
    if not addon.finite(value) then return nil,"Coordonnee invalide" end
    values[#values+1]=value
  end
  if #values~=3 then return nil,"Trois coordonnees X Y Z requises" end
  local shift=kind=="Bloc" and 0.5 or 0
  return {x=values[1]+shift,y=values[2]+shift,z=values[3]+shift}
end

function M.new(snapshot,selected,configuration,onShip,save,validate)
  local state={step=1,form=forms.new(),snapshot=snapshot,drafts={},entries={},id=selected,
    configuration=addon.copy(configuration),onShip=onShip,save=save,validate=validate,barState={}}
  local titles={"Radar","Position","Orientation","Validation"}
  local function radar()
    for _,row in ipairs(state.snapshot.radars or {}) do if row.id==state.id then return row end end
  end
  local function draft()
    if not state.id then return end
    if not state.drafts[state.id] then
      local row=radar()
      local cfg=addon.copy(state.configuration.radars[state.id] or {})
      cfg.apiProfile=cfg.apiProfile or "auto"
      local point=addon.vec({x=cfg.positionX,y=cfg.positionY,z=cfg.positionZ}) or addon.vec(cfg.origin) or row and row.rawPosition
      cfg.positionMode=cfg.positionMode or (row and row.rawPosition and "api" or "manual")
      if cfg.origin then cfg.positionMode="manual" cfg.origin=nil end
      cfg.frame=cfg.frame or (row and row.frame=="world" and "world" or state.onShip and "body" or "world")
      cfg.headingFrame=cfg.headingFrame or (state.onShip and "body" or "world")
      cfg.headingSign,cfg.headingOffset=cfg.headingSign or 1,cfg.headingOffset or 0
      cfg.headingValidated=cfg.headingValidated==true
      state.drafts[state.id]=cfg
      state.entries[state.id]={kind="Centre",text=point and string.format("%.8g %.8g %.8g",point.x,point.y,point.z) or ""}
    end
    return state.drafts[state.id]
  end
  local function candidate()
    local cfg=addon.copy(draft())
    if not cfg then return nil,"Aucun radar selectionne" end
    if cfg.positionMode=="manual" then
      local entry=state.entries[state.id]
      local point,err=M.coordinates(entry.text,entry.kind)
      if not point then return nil,err end
      cfg.positionX,cfg.positionY,cfg.positionZ=point.x,point.y,point.z
    end
    return cfg
  end
  state.candidate=candidate
  local function info(label,value)
    return {label=label,readOnly=true,get=function() return value end}
  end
  function state:update(snapshot)
    self.snapshot=snapshot
  end
  function state:fields()
    local row,cfg=radar(),draft()
    local ids={} for _,value in ipairs(self.snapshot.radars or {}) do ids[#ids+1]=value.id end
    if self.step==1 then
      local caps=row and row.capabilities or {}
      return {{label="Peripherique",options=ids,get=function() return self.id end,set=function(id) self.id=id self.error=nil end},
        cfg and forms.field(cfg,"apiProfile","Profil API",nil,{"auto","4.x","5.0-EA","bridge"}) or info("Profil API","Indisponible"),
        info("Profil actif",row and row.apiProfile or "Inconnu"),
        info("Preuve API",row and row.profileEvidence or "Version non detectable"),
        info("Origine",row and row.adapterOrigin or "API stock / inconnu"),
        info("Limites",row and row.profileLimitation or "Geometrie automatique non verifiee"),
        info("Contacts recus",row and row.rawTrackCount or "Indisponible"),
        info("Position automatique",row and row.rawPosition and "Lecture disponible" or caps.position and "Methode exposee, lecture absente" or "Non exposee"),
        info("Rotation",row and row.rawRotation or "Indisponible"),
        info("Portee (m)",row and row.range or "Indisponible"),
        info("Lectures",row and row.readStatus or "Aucun radar")}
    end
    if not cfg then return {} end
    if self.step==2 then
      local rows={{label="Position",options={"API","Manuel"},get=function() return cfg.positionMode=="manual" and "Manuel" or "API" end,
        set=function(value) cfg.positionMode=value=="Manuel" and "manual" or "api" end},
        {label="Repere",options={"Monde","Sublevel","Inconnu"},get=function() return cfg.frame=="world" and "Monde" or cfg.frame=="body" and "Sublevel" or "Inconnu" end,
        set=function(value) cfg.frame=value=="Monde" and "world" or value=="Sublevel" and "body" or "unknown" end}}
      if cfg.positionMode=="manual" then
        local entry=self.entries[self.id]
        rows[#rows+1]=forms.field(entry,"text","X Y Z","string")
        rows[#rows+1]=forms.field(entry,"kind","Coordonnees",nil,{"Centre","Bloc"})
      else
        local p=row and row.rawPosition
        rows[#rows+1]=info("Position API",p and string.format("%.2f %.2f %.2f",p.x,p.y,p.z) or "Indisponible")
      end
      return rows
    elseif self.step==3 then
      return {forms.field(cfg,"headingSign","Sens de rotation",nil,{1,-1}),
        forms.field(cfg,"headingOffset","Decalage cap (deg)","number"),
        forms.field(cfg,"headingFrame","Repere orientation",nil,{"world","body"}),
        forms.field(cfg,"headingValidated","Orientation verifiee","boolean"),
        forms.field(cfg,"fov","Ouverture cone (optionnel)","number"),
        forms.field(cfg,"heading","Cap fixe (optionnel)","number")}
    end
    local value,err=candidate()
    local position=value and value.positionMode=="manual" and string.format("%.2f %.2f %.2f",value.positionX,value.positionY,value.positionZ) or "API"
    return {info("Radar",self.id),info("Origine",position),info("Repere",cfg.frame),
      info("Orientation",cfg.headingValidated and "Verifiee" or "Non calibree"),
      info("Cone",cfg.fov or "Non calibre"),info("Validation",err or "Configuration prete")}
  end
  function state:draw(w,h)
    if h<12 then renderer.writeAt(1,1,renderer.crop("Setup radar: agrandir la fenetre",w))
      self.bar=ui.toolbar(1,h,w,{{id="cancel",label="Annuler"}}) return end
    renderer.writeAt(1,1,renderer.crop("Setup radar "..self.step.."/4 - "..titles[self.step],w),colors.cyan)
    self.form:draw(w,h,self:fields())
    if self.error then renderer.writeAt(1,h-1,renderer.crop(self.error,w),colors.orange) end
    local buttons={{id="cancel",label="Annuler"}}
    if self.step>1 then buttons[#buttons+1]={id="back",label="Retour"} end
    buttons[#buttons+1]={id="next",label=self.step==4 and "Enregistrer" or "Suivant"}
    self.bar=ui.toolbar(1,h,w,buttons,self.barState)
  end
  function state:action(action)
    if action=="cancel" then self.closed=true return true
    elseif action=="back" then self.step=math.max(1,self.step-1) self.form.scroll=1 self.error=nil return true
    elseif action=="next" then
      local row=radar()
      if not row then self.error="Radar deconnecte / absent" return true end
      if self.step==1 then
        local cfg=draft()
        -- The inspected EA plane-radar implementation already converts plotyard
        -- coordinates to world coordinates; do not transform them a second time.
        if cfg.apiProfile=="5.0-EA" and cfg.positionMode=="api" and row.kind=="fixed" then cfg.frame="world" end
      end
      if self.step>=2 then
        local value,err=candidate()
        if value and value.positionMode=="api" and not row.rawPosition then err="Position API absente; choisir Manuel" end
        if value and not err then local ok,why=self.validate(value) if not ok then err=why end end
        if err then self.error=err return true end
        if self.step==4 then
          local ok,why=self.save(self.id,value)
          if ok then self.closed=true self.saved=true else self.error=tostring(why) end
          return true
        end
      end
      self.step=math.min(4,self.step+1) self.form.scroll=1 self.error=nil return true
    end
    return false
  end
  function state:handle(event)
    if self.form.edit then return self.form:handle(event) end
    if event.name=="mouse_click" then
      for _,box in ipairs(self.bar or {}) do if box.delta and ui.hit(box,event.args[2],event.args[3]) then
        self.barState.first=math.max(1,(self.barState.first or 1)+box.delta) return true
      end end
    end
    local action=event.name=="mouse_click" and ui.toolbarHit(self.bar,event.args[2],event.args[3])
    if action and self:action(action) then return true end
    return self.form:handle(event)
  end
  return state
end
return M
