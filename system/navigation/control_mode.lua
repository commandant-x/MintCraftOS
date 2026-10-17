local M={}
function M.axes(control)
  if control and control.mode=="altitude" then return {"altitude"} end
  return {"pitch","roll","altitude","heading"}
end
function M.enabled(control,axis)
  for _,name in ipairs(M.axes(control)) do if name==axis then return true end end
  return false
end
return M
