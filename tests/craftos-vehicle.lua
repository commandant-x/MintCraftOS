-- Normal GUI, isolated storage; /source is a read-only repository mount.
local ok,err=pcall(function()
  shell.setDir("/") assert(shell.run("/source/install.lua"))
  local model=require("system.navigation.vehicle")
  local diagram=require("system.navigation.vehicle_diagram")
  local profile={type="hexacopter",massKg=126093,com={x=0,y=0,z=0},comVerified=true}
  local channels={}
  for i=1,6 do channels[i]={id="rotor"..i,actuator={role="lift",geometryVerified=true,
    position={x=math.cos(i*math.pi/3)*4,y=0,z=math.sin(i*math.pi/3)*4},direction={x=0,y=1,z=0}}} end
  for _,side in ipairs({false,true}) do
    term.setBackgroundColor(colors.black) term.clear()
    diagram.draw(80,28,model.analyze(profile,channels),profile,side)
    if term.screenshot then term.screenshot() end
    sleep(0.5)
  end
end)
local h=assert(fs.open("/vehicle-result.txt","w"))
h.write(ok and "PASS: native six-rotor body geometry top/side subpixel rendering" or "FAIL: "..tostring(err))
h.close() os.shutdown()
