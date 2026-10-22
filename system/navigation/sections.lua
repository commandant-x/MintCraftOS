-- Eight workspaces; specialist screens remain contextual tools, not global tabs.
local M={}
M.tabs={{id='flight',label='Flight'},{id='autopilot',label='Route'},{id='sublevel',label='Equipment'},{id='vehicle',label='Vehicle / setup'},{id='sweep',label='Altitude'},{id='mapping',label='Outputs'},{id='sensors',label='Sensors'},{id='control',label='Autopilot'}}
M.children={vehicle={{id='drivetrain',label='Motor links'},{id='setup',label='Burner setup'},{id='diagram',label='Diagram'},{id='context',label='Analysis'},{id='estimates',label='Legacy estimates'},{id='frequencies',label='Legacy frequencies'}},sweep={{id='calibration',label='Output tests'},{id='gains',label='Advanced PID'}},mapping={{id='manual',label='Manual inputs'}},sensors={{id='environment',label='Environment'}}}
function M.parent(id)
 if id=='component' then return 'vehicle' end
 if id=='burnerGroup' then return 'vehicle' end
 if id:match('^sweep') then return 'sweep' end
 for parent,children in pairs(M.children) do for _,c in ipairs(children) do if c.id==id then return parent end end end
 return id
end
function M.pages()
 local out={} for _,tab in ipairs(M.tabs) do out[#out+1]=tab end
 for _,parent in ipairs(M.tabs) do for _,child in ipairs(M.children[parent.id] or {}) do out[#out+1]=child end end
 return out
end
return M
