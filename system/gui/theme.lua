local config = require("system.libraries.config")

local M = {}

local themes = {
  mint = {
    desktopBg = colors.green,
    taskbarBg = colors.gray,
    taskbarFg = colors.white,
    windowBg = colors.lightGray,
    windowFg = colors.black,
    titleBg = colors.lime,
    titleFg = colors.black,
    accent = colors.lime,
    buttonBg = colors.gray,
    buttonFg = colors.white,
    error = colors.red,
    warning = colors.orange,
    success = colors.green,
    shadow = colors.black,
  },
  dark = {
    desktopBg = colors.black,
    taskbarBg = colors.gray,
    taskbarFg = colors.white,
    windowBg = colors.gray,
    windowFg = colors.white,
    titleBg = colors.blue,
    titleFg = colors.white,
    accent = colors.cyan,
    buttonBg = colors.lightGray,
    buttonFg = colors.black,
    error = colors.red,
    warning = colors.orange,
    success = colors.lime,
    shadow = colors.black,
  },
}

M.currentId = "mint"
M.current = themes.mint

function M.load()
  local cfg = config.load("/system/config/system.cfg", {})
  M.currentId = cfg.theme or "mint"
  M.current = themes[M.currentId] or themes.mint
end

function M.set(id)
  M.currentId = themes[id] and id or "mint"
  M.current = themes[M.currentId]
  local cfg = config.load("/system/config/system.cfg", {})
  cfg.theme = M.currentId
  config.save("/system/config/system.cfg", cfg)
end

function M.get(name)
  return M.current[name] or themes.mint[name] or colors.white
end

return M
