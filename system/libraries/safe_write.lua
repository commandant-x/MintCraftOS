local M = {}

function M.write(path, content)
  local stage = path .. ".mintcraft-save"
  local old, nextFile = stage .. "/previous", stage .. "/next"
  local handle, owned
  local ok, err = pcall(function()
    if fs.exists(stage) then error("Unfinished save: " .. stage, 0) end
    if fs.exists(path) and fs.isDir(path) then error("Target is a directory", 0) end
    fs.makeDir(stage)
    owned = true
    handle = assert(fs.open(nextFile, "w"), "Cannot open staging file")
    handle.write(content)
    handle.close()
    handle = nil
    if fs.exists(path) then fs.move(path, old) end
    fs.move(nextFile, path)
  end)
  if handle then pcall(handle.close) end
  if not ok then
    if owned then
      local restored, restoreErr = pcall(function()
        if fs.exists(old) then
          if fs.exists(path) then error("Target changed during save", 0) end
          fs.move(old, path)
        end
      end)
      if not restored then return false, tostring(err) .. "; recovery data: " .. stage .. " (" .. tostring(restoreErr) .. ")" end
      pcall(fs.delete, stage)
    end
    return false, tostring(err)
  end
  local cleaned = pcall(fs.delete, stage)
  return true, cleaned and "Saved" or ("Saved; cleanup needed: " .. stage)
end

return M
