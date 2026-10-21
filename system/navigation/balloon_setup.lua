local addon=require("system.libraries.addon")
local link=require("system.navigation.link_output")
local M={}
local function spec(row)
  return {first=row.first.item,second=row.second.item,firstColor=row.first.dyedColor,secondColor=row.second.dyedColor}
end
local function key(value) return link.key({link=value}) end
function M.plan(snapshot,control,endpoints)
  if snapshot.available==false then return nil,"Vehicle Bridge absent : installer le JAR 0.2.1 dans mods serveur et clients, puis redemarrer" end
  if not snapshot.ok then return nil,"Pont indisponible ou perime : "..tostring(snapshot.error or snapshot.status or "Rescan requis") end
  local complete=snapshot.inventoryComplete
  if complete==nil then complete=snapshot.complete end
  if not complete then return nil,"Inventaire incomplet : corriger les erreurs/limites du pont avant Detect" end
  if not snapshot.burnerDiscoveryAvailable then return nil,"Installer le pont 0.2.1 pour detecter les bruleurs" end
  if #(snapshot.burners or {})==0 then return nil,"Aucun bruleur detecte sur ce sublevel" end
  local p={vehicleId=snapshot.vehicleId,burnerIds={},endpoints={},connected=0,baseline=nil}
  local baseline,uniform,shared,consistent=nil,true,nil,true
  local occupied={}
  for _,r in ipairs(snapshot.links) do occupied[key(spec(r))]=true end
  for _,c in ipairs(control.channels or {}) do local k=c.backend=="frequency" and key(c.link) if k then occupied[k]=true end end
  for _,burner in ipairs(snapshot.burners) do
    p.burnerIds[#p.burnerIds+1]=burner.id
    if burner.hasBalloon then p.connected=p.connected+1 end
    if baseline==nil then baseline=burner.signal elseif baseline~=burner.signal then uniform=false end
    local adjacent,selected=0,nil
    for _,r in ipairs(snapshot.links) do
      local a,b=burner.position,r.position
      if r.receiver and math.abs(math.abs(a.x-b.x)+math.abs(a.y-b.y)+math.abs(a.z-b.z)-1)<0.01 then
        adjacent=adjacent+1 selected=spec(r)
      end
    end
    if adjacent~=1 then consistent=false
    elseif not shared then shared=selected
    elseif key(shared)~=key(selected) then consistent=false end
  end
  if uniform then p.baseline=baseline end
  p.burnerCount=#p.burnerIds
  if consistent and shared then p.frequency=shared p.reused=true end
  if not p.frequency then
    for _,color in ipairs({"white","orange","magenta","light_blue","yellow","lime","pink","gray","light_gray","cyan","purple","blue","brown","green","red","black"}) do
      local item="minecraft:"..color.."_wool"
      local candidate={first=item,second=item}
      if not occupied[key(candidate)] then p.frequency=candidate break end
    end
  end
  if not p.frequency then return nil,"Les frequences proposees sont deja utilisees; choisir une paire manuellement" end
  for _,e in ipairs(endpoints) do if e.backend=="frequency" then p.endpoints[#p.endpoints+1]=e.name end end
  p.transmitter=#p.endpoints==1 and p.endpoints[1] or ""
  return p
end
function M.diagnostics(snapshot)
  local rows={"Pont : "..tostring(snapshot.status or (snapshot.ok and "recent" or "indisponible"))}
  if snapshot.error then rows[#rows+1]=tostring(snapshot.error) end
  if snapshot.available==false then
    rows[#rows+1]="Installer Vehicle Bridge 0.2.1 dans mods serveur ET clients, puis redemarrer."
    return rows
  end
  rows[#rows+1]="Version du pont : "..tostring(snapshot.bridgeVersion or "inconnue")
  rows[#rows+1]="Detection passive : aucun signal emis."
  for _,err in ipairs(snapshot.errors or {}) do rows[#rows+1]="Pont : "..err end
  rows[#rows+1]="Geometrie : "..(snapshot.complete and "complete" or "partielle").." / inventaire : "..((snapshot.inventoryComplete==true or (snapshot.inventoryComplete==nil and snapshot.complete)) and "complet" or "partiel")
  for _,b in ipairs(snapshot.burners or {}) do
    rows[#rows+1]=b.id
    rows[#rows+1]="  signal "..tostring(b.signal).."/15 / gaz "..tostring(b.gasOutput)
    rows[#rows+1]="  ballon "..(b.hasBalloon and "associe" or "non confirme").." / gaz actif "..(b.gasActive and "oui" or "non")
    if not b.hasBalloon then rows[#rows+1]="  Calibration > Initialize (2s), puis Rescan ; verifier enveloppe et degagement." end
  end
  if #(snapshot.burners or {})==0 then rows[#rows+1]="Aucun bruleur visible : verifier le Computer sur le vaisseau assemble." end
  rows[#rows+1]="Signal/gaz ne prouvent pas le vol stationnaire : calibration physique requise."
  return rows
end
function M.create(control,plan,options)
  if not plan or not plan.frequency or not key(plan.frequency) then return nil,"Frequence manquante" end
  local known=false
  for _,name in ipairs(plan.endpoints) do if name==options.transmitter then known=true end end
  if not known then return nil,"Choisir un CC Create Redstone Link Bridge detecte" end
  if options.wiringConfirmed~=true then return nil,"Confirmer le cablage des recepteurs" end
  for _,field in ipairs({"neutral","rescue"}) do
    local v=options[field]
    if not addon.finite(v) or v%1~=0 or v<0 or v>15 then return nil,"Signal "..field.." invalide (0..15)" end
  end
  if #(control.channels or {})>0 and not options.replaceExisting then return nil,"Remplacement des commandes existantes non confirme" end
  local out=addon.copy(control)
  out.mode="altitude" out.channels={{id="balloon-burners",backend="frequency",name=options.transmitter,
    link=addon.copy(plan.frequency),min=0,max=15,neutral=options.neutral,rescue=options.rescue,
    mix={altitude=options.inverted and -1 or 1},validated=false,frequency=plan.frequency.first.." + "..plan.frequency.second,
    actuator={role="buoyancy",position={x=0,y=0,z=0},direction={x=0,y=0,z=0},geometryVerified=false}}}
  out.vehicle=out.vehicle or {} out.vehicle.type="airship"
  out.gains=out.gains or {}
  out.gains.altitude={kp=0,ki=0,kd=0,limit=1,slew=0.5,integralLimit=1,deadband=0}
  out.manualInputs={}
  for _,binding in ipairs(control.manualInputs or {}) do if binding.axis=="altitude" then out.manualInputs[#out.manualInputs+1]=addon.copy(binding) end end
  out.balloonSetup={vehicleId=plan.vehicleId,burnerIds=addon.copy(plan.burnerIds),wiringConfirmed=true}
  out.hoverValidated,out.rescueValidated,out.manualValidated=false,false,false
  out.enabled=false
  return out
end
return M
