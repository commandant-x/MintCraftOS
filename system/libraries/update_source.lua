local M = {}

local function validRepo(value)
  if type(value) ~= "string" then return false end
  local owner, repo = value:match("^([%w_-]+)/([%w_.-]+)$")
  return owner ~= nil and repo ~= "." and repo ~= ".."
end

local function validSha(value)
  return type(value) == "string" and #value == 40 and value:match("^%x+$") ~= nil
end

function M.resolve(cfg, get)
  if not validRepo(cfg.repo) then
    return nil, "Invalid GitHub repository"
  end
  local ref = cfg.branch
  if type(ref) ~= "string" or ref == "" then return nil, "Invalid GitHub ref" end
  local sha = ref
  if not validSha(sha) then
    local encoded = ref:gsub("([^%w_.~-])", function(c) return string.format("%%%02X", c:byte()) end)
    local body, err = get("https://api.github.com/repos/" .. cfg.repo .. "/commits/" .. encoded)
    if not body then return nil, err end
    local ok, data = pcall(textutils.unserializeJSON, body)
    if not ok or type(data) ~= "table" or not validSha(data.sha) then
      return nil, "GitHub did not return a valid commit SHA"
    end
    sha = data.sha
  end
  return { repo = cfg.repo, sha = sha:lower() }
end

function M.url(source, file)
  assert(type(source) == "table" and validSha(source.sha), "Pinned commit required")
  assert(validRepo(source.repo), "Invalid repository")
  assert(file == "VERSION" or file == "install.lua", "Invalid release file")
  return "https://raw.githubusercontent.com/" .. source.repo .. "/" .. source.sha .. "/" .. file
end

return M
