-- Profile demand router only. No transmission/gearshift/spring/Link actuation.
local s=_G.MintCraftVehicle
if not s then s={label=ui.label('Profils: 1 ballon, 2 quad; demandes uniquement')} _G.MintCraftVehicle=s end
addElement(s.label)
local profile=input('Profile')
local drive=input('Forward demand') local turn=input('Left demand')
local lift=input('Collective demand')
local front=input('Front correction') local right=input('Right correction')
local tiltLimit=input('Measured tilt limit deg')
local tiltQualified=input('Tilt response qualified')
local stop=input('Horizontal STOP')
if stop~=0 then drive,turn=0,0 end
local balloon,quad,intent,issue
if profile==1 then balloon,issue=Mixer.balloon(drive,turn,lift)
elseif profile==2 then
 -- STOP requests a level attitude; it does not prove braking/position hold.
 if stop~=0 then front,right=0,0 end
 quad,issue=Mixer.quadLift(lift,front,right)
 if quad and (drive~=0 or turn~=0) then
  intent,issue=Mixer.quadIntent(drive,turn,tiltLimit,tiltQualified==1)
 end
else issue='Choisir profil 1 ballon ou 2 quad' end
local valid=(balloon or quad) and not issue
s.label.setText(issue or (profile==1 and 'Ballon: 5 frequences; demandes sans actionnement' or 'Quad: 4 sustentations; inclinaison via boucle attitude requise'))
output('Profile valid',valid and 1 or 0)
output('Single drive demand',valid and balloon and balloon.drive or 0)
output('Reverse requested',valid and balloon and balloon.reverseRequested and 1 or 0)
output('Spring left demand',valid and balloon and balloon.steerLeft or 0)
output('Spring right demand',valid and balloon and balloon.steerRight or 0)
-- Lift validity is separate: an unavailable horizontal axis never cuts lift.
output('Lift valid',(balloon or quad) and 1 or 0)
output('Single lift demand',balloon and balloon.lift or 0)
output('Front left demand',quad and quad.frontLeft or 0)
output('Front right demand',quad and quad.frontRight or 0)
output('Rear left demand',quad and quad.rearLeft or 0)
output('Rear right demand',quad and quad.rearRight or 0)
output('Forward tilt target deg',intent and intent.forwardTilt or 0)
output('Left tilt target deg',intent and intent.leftTilt or 0)
output('Tilt target valid',valid and quad and tiltQualified==1 and 1 or 0)
output('Yaw available',0)
output('Flight qualified',0)
