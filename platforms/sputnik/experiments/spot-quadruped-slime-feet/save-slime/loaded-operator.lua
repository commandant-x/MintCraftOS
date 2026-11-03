-- Experimental operator interface; no balance or contact feedback.
local s=_G.MintSpotOperator
if not s then
 s={enable=ui.checkbox('Armer les commandes redstone'),start=ui.checkbox('Lancer les huit mouvements (decocher avant nouvelle sequence)'),label=ui.label('Moteur a 8 tr/min ; essai sur terrain plat uniquement')}
 _G.MintSpotOperator=s
end
addElement(s.enable);addElement(s.start);addElement(s.label)
output('Enable',s.enable.isChecked() and 1 or 0)
output('Start',s.start.isChecked() and 1 or 0)
