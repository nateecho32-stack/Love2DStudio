-- Settings: defaults-as-schema with validation rules, flat dotted-key storage,
-- versioned file with a future-version guard and one-time heals.
-- Adapted from 2d Trippy Hell game/systems/core/settings.lua + save/settings_store.lua.

local M = {}

local function split(path)
  local parts = {}
  for part in path:gmatch("[^.]+") do parts[#parts + 1] = part end
  return parts
end

-- returns (parentTable, leafValue)
local function walk(t, parts)
  local node = t
  for i = 1, #parts - 1 do
    node = node[parts[i]]
    if type(node) ~= "table" then return nil, nil end
  end
  return node, node[parts[#parts]]
end

local function flatten(t, prefix, out)
  for k, v in pairs(t) do
    local path = prefix and (prefix .. "." .. k) or k
    if type(v) == "table" then flatten(v, path, out) else out[path] = v end
  end
  return out
end

local function applyRule(rule, v)
  if v == nil then return nil, "value missing" end
  local tv = type(v)
  if rule then
    if rule.values then
      local ok = false
      for i = 1, #rule.values do
        if rule.values[i] == v then ok = true break end
      end
      if not ok then return nil, "not an allowed value" end
    end
    if tv == "number" then
      if v ~= v or v == math.huge or v == -math.huge then return nil, "number out of range" end
      if rule.min and v < rule.min then v = rule.min end
      if rule.max and v > rule.max then v = rule.max end
      if rule.integer then v = math.floor(v + 0.5) end
    elseif tv == "string" then
      v = tostring(v)
      if rule.maxLen and #v > rule.maxLen then v = v:sub(1, rule.maxLen) end
      if rule.nonempty and #v == 0 then return nil, "string must not be empty" end
    elseif tv ~= "boolean" then
      return nil, "unsupported value type: " .. tv
    end
  else
    if tv ~= "number" and tv ~= "string" and tv ~= "boolean" then
      return nil, "unsupported value type: " .. tv
    end
  end
  return v
end

local function escape(s)
  return s:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("=", "\\e")
end

local function unescape(s)
  return s:gsub("\\e", "="):gsub("\\r", "\r"):gsub("\\n", "\n"):gsub("\\\\", "\\")
end

-- coerce a stored string to the type the default already has (defaults are the schema)
local function coerce(v, want)
  local tw = type(want)
  if tw == "number" then return tonumber(v) end
  if tw == "boolean" then
    if v == "true" then return true end
    if v == "false" then return false end
    return nil
  end
  return v
end

-- opts: { file=, version=, defaults=, rules={ ["path"]={min,max,integer,values,maxLen,nonempty} }, heals={ {min=, fn=} } }
function M.new(opts)
  opts = opts or {}
  local S = {
    file = opts.file or "settings.dat",
    version = opts.version or 1,
    defaults = opts.defaults or {},
    rules = opts.rules or {},
    heals = opts.heals or {},
  }
  S.values = M._deepCopy(S.defaults)

  function S:get(path)
    local _, v = walk(S.values, split(path))
    return v
  end

  -- writes anywhere (creates nesting); returns true or nil, reason
  function S:set(path, v)
    local fixed, why = applyRule(S.rules[path], v)
    if fixed == nil then return nil, why end
    local node = S.values
    local parts = split(path)
    for i = 1, #parts - 1 do
      local nextNode = node[parts[i]]
      if type(nextNode) ~= "table" then nextNode = {} node[parts[i]] = nextNode end
      node = nextNode
    end
    node[parts[#parts]] = fixed
    return true
  end

  function S:serialize()
    local flat = flatten(S.values, nil, {})
    local keys = {}
    for k in pairs(flat) do keys[#keys + 1] = k end
    table.sort(keys)
    local lines = { "version=" .. S.version }
    for _, path in ipairs(keys) do
      local v = flat[path]
      local sv = type(v) == "string" and escape(v) or tostring(v)
      lines[#lines + 1] = path .. "=" .. sv
    end
    return table.concat(lines, "\n") .. "\n"
  end

  function S:save()
    if not (love and love.filesystem) then return false, "no filesystem" end
    return love.filesystem.write(S.file, S:serialize())
  end

  -- readFn(file) -> content|nil overrides love.filesystem (for tests)
  -- returns ok, accepted, healed, fileVersion
  function S:load(readFn)
    local content
    if readFn then
      content = readFn(S.file)
    elseif love and love.filesystem then
      content = love.filesystem.read(S.file)
    end
    if not content then return false, 0, 0, nil end

    local fileVersion, flat = 0, {}
    for line in content:gmatch("[^\r\n]+") do
      local k, v = line:match("^(.-)=(.*)$")
      if k == "version" then
        fileVersion = tonumber(v) or 0
      elseif k then
        flat[k] = v
      end
    end
    -- an older binary must refuse a newer file: merging would silently
    -- downgrade and destroy future-version preferences on re-save
    if fileVersion > S.version then return false, 0, 0, fileVersion end

    local defaultsFlat = flatten(S.defaults, nil, {})
    local accepted = 0
    for path, sv in pairs(flat) do
      local want = defaultsFlat[path]
      if want ~= nil then -- unknown keys are dropped
        local v = coerce(unescape(sv), want) -- unescape BEFORE rules: maxLen must count real chars
        if v ~= nil then
          local fixed = applyRule(S.rules[path], v)
          if fixed ~= nil then
            local node = S.values
            local parts = split(path)
            for i = 1, #parts - 1 do node = node[parts[i]] end
            node[parts[#parts]] = fixed
            accepted = accepted + 1
          end
        end
      end
    end

    local healed = 0
    for _, heal in ipairs(S.heals) do
      if fileVersion < heal.min then
        heal.fn(S, fileVersion)
        healed = healed + 1
      end
    end
    return true, accepted, healed, fileVersion
  end

  return S
end

function M._deepCopy(t)
  local out = {}
  for k, v in pairs(t) do
    out[k] = type(v) == "table" and M._deepCopy(v) or v
  end
  return out
end

return M
