-- Read-only cockpit presentation. Inputs are service caches, never peripherals.
local A=require('system.libraries.addon')
local M={}
local function num(v) return A.finite(v) and string.format('%.2f',v) or '?' end
local function fresh(at,now,age) return A.finite(now) and A.finite(at) and at<=now and now-at<=age end
function M.rows(state,t,pose,now)
 state,t,pose=state or {},t or {},pose or {}
 local rows={} local function row(title,text)
  text=tostring(text or 'Indisponible') if #text>384 then text=text:sub(1,381)..'...' end
  rows[#rows+1]={title=title,description=text}
 end
 local live=fresh(state.timestamp,now,.5)
 local world=type(pose.vehicleId)=='string' and #pose.vehicleId>0 and #pose.vehicleId<=128 and pose.frame=='world' and pose.inSublevel==true and fresh(pose.timestamp,now,.5)
 local armed=live and state.state=='armed'
 local hold=state.measuredHold
 local known=state.knownOutputHold
 local measured=fresh(t.timestamp,now,.5)
 local altitude=measured and t.altitude or nil local heading=measured and t.heading or nil
 row('AUTOPILOT | etat actuel',(live and tostring(state.state or 'inconnu') or 'Etat du service perime')..' | '..tostring(state.reason or ''))
 row('Vaisseau',world and tostring(pose.vehicleId or 'inconnu') or 'Pose monde fraiche indisponible')
 row('Maintien vertical automatique',not live and 'Etat perime | attendre le service' or armed and hold and hold.active and 'ACTIF | modele mesure et protections du service' or armed and known and known.axes and known.axes.vertical and 'ACTIF | sorties mesurees et qualification locale en boucle fermee' or 'Inactif | initialiser et qualifier si necessaire')
 row('Guidage differentiel',not live and 'Etat perime | attendre le service' or armed and state.differentialReady and 'DISPONIBLE | avant/arriere et lacet mesures' or state.differentialReason or 'Non qualifie actuellement')
 row('Consignes altitude',num(altitude)..' m mesuree | '..num((state.targets or {}).altitude)..' m demandee')
 row('Consignes vitesse / cap',num(live and world and state.groundSpeed or nil)..' m/s mesuree | '..num(heading)..' deg mesure | '..num((state.pilot or {}).speed)..' m/s et '..num((state.pilot or {}).heading)..' deg demandes')
 if hold then
  row('Chauffe',num(hold.requestedHeat)..'/15 demandee | dernier signal demande '..num(hold.heat))
  local trim=hold.adaptation
  if trim then row('Adaptation de masse',tostring(trim.phase or 'apprentissage')..' | correction '..num(trim.bias)..' | '..tostring(trim.reason or '')..' | ne recertifie pas les moteurs') end
 end
 if armed and known then
  local available={} for _,axis in ipairs({'forward','right','vertical','pitch','yaw','roll'}) do if known.axes and known.axes[axis] then available[#available+1]=axis end end
  row('Axes qualifies localement',table.concat(available,' / ')..' | '..tostring(known.strategy)..' | domaine observe uniquement')
  local progress=state.outputCharacterization and state.outputCharacterization.progress
  if progress then row('Convergence physique',progress.reason) end
 else row('Translation laterale / attitude','Automatique non qualifie | aucune nouvelle autorite droite, tangage ou roulis certifiee par ces diagnostics') end
 local proof=state.autoCalibration or {}
 local outputs=state.outputCharacterization
 if outputs then proof=outputs.qualification or outputs end
 row('Calibration',tostring(proof.state or 'non effectuee')..' / '..tostring(proof.phase or '')..' | '..tostring(proof.reason or 'Initialiser dans une zone libre'))
 local checks={} for _,name in ipairs({'hover','down','up','return','rescue','priority','horizontal'}) do
  local c=(proof.checks or {})[name] checks[#checks+1]=name..'='..(c and c.passed and 'mesure' or 'non valide')
 end
 if outputs and outputs.qualification then row('Tests observes dans la session',tostring(#(outputs.qualification.checks or {}))..' deplacements/retours qualifies | '..tostring(outputs.qualification.reason)) else row('Tests observes dans la session',table.concat(checks,' | ')) end
 row('Reprise manuelle',proof.manualSwitch or 'Le test logiciel ne prouve pas un interrupteur materiel')
 if state.sweep then row('Mesure altitude',state.sweep.state..' | '..tostring(state.sweep.reason or '')) end
 local k=state.kinematics or {}
 local observed=live and world and k.vehicleId==pose.vehicleId and k.available==true and k.frame=='world' and fresh(k.observedAt,now,.5) and A.finite(k.validUntil) and now<=k.validUntil and k.body and k.body.frame=='body_orientation_at_last_pose' and
  k.responseUnits and k.responseUnits.translation=='block/s2' and k.responseUnits.rotation=='deg/s2'
 row('Observations six axes',observed and 'Fraiches | derivees de pose ; aucune certification de commande' or 'Indisponibles/perimees | '..tostring(k.reason or 'Mesures consecutives requises'))
 if observed then
  local r=k.response or {}
  row('Acceleration observee', 'avant '..num(r.forward)..' | droite '..num(r.right)..' | verticale '..num(r.vertical)..' blocs/s2')
  row('Rotation observee','tangage '..num(r.pitch)..' | lacet '..num(r.yaw)..' | roulis '..num(r.roll)..' deg/s2 | repere corps a la derniere pose')
 end
 local experiments=state.motorExperiments or {} local usable,count=0,0
 for i,g in ipairs(experiments.groups or {}) do
  if i>4 then break end count=count+1 if g.usable then usable=usable+1 end
  row('Observation moteur '..i,tostring((g.command or {}).side or '?')..' / rapport '..num((g.command or {}).gear)..' / inverseur '..num((g.command or {}).reverse)..' | '..tostring(g.reason or 'Donnees insuffisantes'))
 end
 row('Donnees moteur',usable..'/'..count..' groupes exploitables dans la session | diagnostic, pas un certificat de controle')
 local brake=state.predictiveBraking
 row('Freinage observe',brake and ('deceleration '..num(brake.deceleration)..' blocs/s2 | delai '..num(brake.reactionTime)..' s | vitesse observee '..num(brake.maxObservedSpeed)..' blocs/s ; domaine empirique'..(armed and state.differentialReady and '' or ' | reference, guidage indisponible')) or 'Enveloppe de freinage indisponible')
 local mechanical=state.mechanicalDiagnostic or {}
 local currentMechanical=armed and mechanical.available and fresh(mechanical.observedAt,now,2) and A.finite(mechanical.validUntil) and now<=mechanical.validUntil
 row('Retour mecanique moteur',currentMechanical and (tostring(mechanical.qualifiedRoots or 0)..' sources observees | '..tostring(mechanical.reason or '')..' | couverture partielle') or 'Indisponible/perime | aucune liaison mecanique supposee')
 local issue=(state.horizontalDiagnostic or {}).issue
 if issue then row('Navigation suspendue',issue) end
 local mission=state.autopilot or {}
 row('Trajet',tostring(mission.state or 'inactif')..' | '..tostring(mission.reason or 'Aucune mission active'))
 if mission.count and mission.count>0 then row('Progression trajet',tostring(mission.index or '?')..'/'..tostring(mission.count)..' | distance '..num(mission.distance)..' blocs | approche '..num(mission.brakingSpeed)..' blocs/s') end
 row('ATLAS / atterrissage','Selecteur X/Z sans terrain ni evitement garanti | atterrissage automatique non qualifie')
 row('Arret et proprietaire','STOP/F10 reste immediat | fermer Navigation applique le secours | aucun rearmement automatique')
 return rows
end
return M
