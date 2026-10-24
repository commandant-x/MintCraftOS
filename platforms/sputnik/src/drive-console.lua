-- Differential demand generator only: no actuator API calls, no lift output.
local s=_G.MintCraftDrive
if not s then
 s={label=ui.label('Demandes uniquement, jamais des signaux transmission'),lift=ui.label('4 sustentations independantes; pas de maintien qualifie')}
 _G.MintCraftDrive=s
end
addElement(s.label) addElement(s.lift)
local drive=input('Drive') local turn=input('Left turn') local mode=input('Blend mode')
local stop=input('Drive STOP')
if stop~=0 then drive,turn=0,0 end
local result,why=Mixer.differential(drive,turn,mode==1 and 'blend' or 'pivot')
local left,right=0,0
if result then left,right=result.left,result.right end
s.label.setText(result and ('Demande G '..string.format('%.2f',left)..' / D '..string.format('%.2f',right)..'; pas des signaux 0..15') or tostring(why))
output('Left signed demand',left)
output('Right signed demand',right)
output('Left reverse requested',left<0 and 1 or 0)
output('Right reverse requested',right<0 and 1 or 0)
output('Demands valid',result and 1 or 0)
local collective=input('Lift collective') local front=input('Front bias') local rightBias=input('Right bias')
local lift,issue=Mixer.quadLift(collective,front,rightBias)
s.lift.setText(lift and ('Moyenne '..string.format('%.2f',lift.collective)..' / corrections '..string.format('%.2f',lift.attitudeScale)..'; aucune preuve de poussee') or tostring(issue))
output('Front left lift demand',lift and lift.frontLeft or 0)
output('Front right lift demand',lift and lift.frontRight or 0)
output('Rear left lift demand',lift and lift.rearLeft or 0)
output('Rear right lift demand',lift and lift.rearRight or 0)
output('Lift demands valid',lift and 1 or 0)
output('Flight qualified',0)
