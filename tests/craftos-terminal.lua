-- Simulated CC Terminals transport over a real native CraftOS-PC framebuffer.
-- This is not a real Minecraft peripheral test.
_G.mintcraftTerminalFixture=true
assert(loadfile("/source/tests/craftos-graphics.lua","t",_ENV))()
