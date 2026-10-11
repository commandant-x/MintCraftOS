local M = {}
local moduleIndex, moduleTime
local symbolCache = setmetatable({}, { __mode = "k" })

function M.invalidate()
  moduleIndex, moduleTime = nil, nil
  symbolCache = setmetatable({}, { __mode = "k" })
end

local luaWords = {
  "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
  "if", "in", "local", "nil", "not", "or", "repeat", "return", "then",
  "true", "until", "while", "pairs", "ipairs", "pcall", "print", "require",
}

local ccWords = {
  "fs.open", "fs.exists", "fs.list", "fs.combine", "term.setCursorPos",
  "term.getSize", "textutils.serialize", "os.pullEvent", "os.reboot",
  "peripheral.find", "rednet.open", "http.get", "window.create",
  "table.insert", "table.remove", "string.sub", "string.match",
}

local terminalCommands = {
  "ls", "cd", "pwd", "mkdir", "cp", "mv", "rm", "trash", "restore", "cat", "type",
  "edit", "open", "clear", "ps", "kill", "logs", "browser", "crafttube", "messenger", "navigation", "combat", "store", "install", "files", "settings", "devices",
  "whoami", "lock", "unlock", "login", "logout", "passwd",
  "reboot", "help",
}

local snippets = {
  { label = "function", insert = "function name(args)\n  \nend", kind = "snippet" },
  { label = "if", insert = "if condition then\n  \nend", kind = "snippet" },
  { label = "for", insert = "for i = 1, n do\n  \nend", kind = "snippet" },
  { label = "while", insert = "while condition do\n  \nend", kind = "snippet" },
  { label = "repeat", insert = "repeat\n  \nuntil condition", kind = "snippet" },
  { label = "pcall", insert = "local ok, err = pcall(function()\n  \nend)", kind = "snippet" },
  { label = "require", insert = "local mod = require(\"module\")", kind = "snippet" },
}

local function add(rows, seen, label, insert, kind)
  if label and label ~= "" and not seen[label] then
    seen[label] = true
    table.insert(rows, { label = label, insert = insert or label, kind = kind or "word" })
  end
end

local function listModules()
  local now = os.clock()
  if moduleIndex and now - moduleTime < 5 then return moduleIndex end
  local rows = {}
  local function walk(path)
    if not fs.exists(path) then return end
    for _, name in ipairs(fs.list(path)) do
      local full = fs.combine(path, name)
      if fs.isDir(full) then
        walk(full)
      elseif name:match("%.lua$") then
        local module = full:gsub("^/", ""):gsub("%.lua$", ""):gsub("/", ".")
        table.insert(rows, module)
      end
    end
  end
  walk("/system")
  walk("/apps")
  table.sort(rows)
  moduleIndex, moduleTime = rows, now
  return rows
end

local function localSymbols(lines)
  local found = {}
  for _, line in ipairs(lines or {}) do
    local name = line:match("^%s*local%s+function%s+([%w_]+)")
    if name then found[name] = true end
    name = line:match("^%s*function%s+([%w_%.]+)")
    if name then found[name] = true end
    for localName in line:gmatch("local%s+([%w_]+)") do found[localName] = true end
  end
  local rows = {}
  for name in pairs(found) do table.insert(rows, name) end
  table.sort(rows)
  return rows
end

function M.prefix(text, cursor, pattern)
  local left = tostring(text or ""):sub(1, (cursor or 1) - 1)
  return left:match(pattern or "([%w_%.%-/]+)$") or ""
end

local function symbols(ctx)
  local lines = ctx.lines or {}
  if ctx.revision == nil then return localSymbols(lines) end
  local entry = symbolCache[lines]
  if not entry or entry.revision ~= ctx.revision then
    entry = { revision = ctx.revision, rows = localSymbols(lines) }
    symbolCache[lines] = entry
  end
  return entry.rows
end

function M.suggest(ctx)
  ctx = ctx or {}
  local prefix = ctx.prefix or M.prefix(ctx.text or "", ctx.cursor or 1, ctx.pattern)
  if prefix == "" then return nil end

  local rows, seen = {}, {}
  if ctx.mode == "terminal" then
    local before = ctx.text and ctx.text:sub(1, (ctx.cursor or (#ctx.text + 1)) - #prefix - 1) or ""
    if before:match("^%s*$") then
    for _, cmd in ipairs(terminalCommands) do
      if cmd:sub(1, #prefix) == prefix then return { label = cmd, insert = cmd, kind = "command" } end
    end
    end
    local dir = ctx.cwd or "/"
    local part = prefix
    local base = prefix:match("^(.*)/")
    if base then
      base = base .. "/"
      part = prefix:sub(#base + 1)
      dir = base:sub(1, 1) == "/" and base or fs.combine(ctx.cwd or "/", base)
    end
    if fs.exists(dir) and fs.isDir(dir) then
      for _, name in ipairs(fs.list(dir)) do
        if name:sub(1, #part) == part then
          local value = (base or "") .. name
          if fs.isDir(fs.combine(dir, name)) then value = value .. "/" end
          add(rows, seen, value, value, "path")
          return rows[1]
        end
      end
    end
  else
    for _, item in ipairs(snippets) do
      if item.label:sub(1, #prefix) == prefix then return { label = item.label, insert = item.insert, kind = item.kind } end
    end
    for _, word in ipairs(luaWords) do
      if word:sub(1, #prefix) == prefix then return { label = word, insert = word, kind = "lua" } end
    end
    for _, word in ipairs(ccWords) do
      if word:sub(1, #prefix) == prefix then return { label = word, insert = word, kind = "cc" } end
    end
    for _, word in ipairs(symbols(ctx)) do
      if word:sub(1, #prefix) == prefix and word ~= prefix then return { label = word, insert = word, kind = "local" } end
    end
    if #rows == 0 then
      for _, mod in ipairs(listModules()) do
        if mod:sub(1, #prefix) == prefix then return { label = mod, insert = mod, kind = "module" } end
      end
    end
  end

  return rows[1]
end

function M.apply(text, cursor, suggestion, prefix)
  text = tostring(text or "")
  cursor = cursor or 1
  if not suggestion then return text, cursor end
  prefix = prefix or M.prefix(text, cursor)
  local before = text:sub(1, cursor - #prefix - 1)
  local after = text:sub(cursor)
  local insert = suggestion.insert or suggestion.label or ""
  return before .. insert .. after, #before + #insert + 1
end

function M.commands()
  return terminalCommands
end

return M
