local h=fs.open('/startup.lua','r')
local startup=h and h.readAll() if h then h.close() end
local marker='-- MintCraft NEXUS bootstrap v1'
assert(type(startup)=='string' and startup:sub(1,#marker)==marker,'Non-NEXUS startup protected')
print('Eject the provisioning disk and remove this ID from the MASTER first.')
print('Type UNINSTALL to remove only /nexus and the NEXUS startup:')
if read()~='UNINSTALL' then print('Cancelled') return end
fs.delete('/startup.lua')
fs.delete('/nexus')
print('NEXUS removed. Other files were not changed.')
