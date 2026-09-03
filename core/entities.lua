-- Archetype registry + spawner: content is data, and every spawned entity's
-- props validate against the archetype's typed schema. The editor inspector
-- generates its fields from the same schema (Pass 6). Pattern from Void Place
-- entities/init.lua.

local root = (...):match("^(.-)core%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local registryMod = R("core.registry")
local tablex = R("core.tablex")

local entities = {}

-- opts: { ecs = ecs world }
function entities.new(opts)
  local E = {
    ecs = assert(opts and opts.ecs, "entities needs an ecs world"),
    defs = registryMod.new(),
  }

  -- def = {
  --   schema = { prop = { type = "number"|"string"|"boolean"|"enum",
  --                      default = v, min =, max =, values = {...} } },
  --   size = { w, h },               -- editor hit-test bounds
  --   components = { name = data or fn(entityId, props) },
  --   init = function(ecs, entityId, props) end,
  -- }
  function E:define(id, def)
    def.schema = def.schema or {}
    def.size = def.size or { w = 24, h = 24 }
    self.defs:register(id, def)
    return def
  end

  function E:def(id) return self.defs:get(id) end
  function E:schema(id)
    local d = self.defs:get(id)
    return d and d.schema or nil
  end
  function E:archetypeIds() return self.defs:ids() end

  -- fills defaults, coerces types, clamps numbers, validates enums.
  -- unknown props are DROPPED (schema is the contract). returns props | nil, reason
  function E:validate(id, props)
    local def = self.defs:get(id)
    if not def then return nil, "unknown archetype: " .. tostring(id) end
    local out = {}
    for name, spec in pairs(def.schema) do
      local v = props and props[name]
      if v == nil then v = spec.default end
      local tv = type(v)
      if spec.type == "number" then
        if tv == "string" then v = tonumber(v) tv = type(v) end
        if tv ~= "number" or v ~= v or v == math.huge or v == -math.huge then
          v = spec.default
        end
        if type(v) == "number" then
          if spec.min and v < spec.min then v = spec.min end
          if spec.max and v > spec.max then v = spec.max end
        end
      elseif spec.type == "boolean" then
        if tv ~= "boolean" then v = spec.default or false end
      elseif spec.type == "enum" then
        local ok = false
        for _, allowed in ipairs(spec.values or {}) do
          if allowed == v then ok = true break end
        end
        if not ok then v = spec.default end
      else -- string
        v = v ~= nil and tostring(v) or (spec.default or "")
      end
      out[name] = v
    end
    return out
  end

  -- returns entityId | nil, reason
  function E:spawn(id, x, y, props)
    local def = self.defs:get(id)
    if not def then return nil, "unknown archetype: " .. tostring(id) end
    local valid = self:validate(id, props)
    if not valid then return nil, "invalid props" end
    local entityId = self.ecs:spawn()
    self.ecs:add(entityId, "transform", { x = x or 0, y = y or 0, rot = 0, scale = 1 })
    self.ecs:add(entityId, "archetype", { id = id, props = valid })
    for name, data in pairs(def.components or {}) do
      self.ecs:add(entityId, name, type(data) == "function" and data(entityId, valid) or data)
    end
    if def.init then def.init(self.ecs, entityId, valid) end
    return entityId
  end

  -- scene-data direction (Pass 5 contract with save/scenedata.lua)
  function E:serializeAll()
    local out = {}
    self.ecs:each("transform", function(id, transform)
      local arch = self.ecs:get(id, "archetype")
      if arch then
        local entry = { type = arch.id, x = transform.x, y = transform.y, props = arch.props }
        if transform.rot ~= 0 then entry.rot = transform.rot end
        if transform.scale ~= 1 then entry.scale = transform.scale end
        out[#out + 1] = entry
      end
    end)
    return out
  end

  function E:deserialize(list)
    local ids = {}
    for _, e in ipairs(list or {}) do
      local props = e.props
      -- carry rot/scale through spawn via underscore keys, then fix the transform
      local rot, scale = e.rot or 0, e.scale or 1
      if props then
        props = tablex.deepCopy(props)
      else
        props = {}
      end
      local id = self:spawn(e.type, e.x, e.y, props)
      if id then
        local transform = self.ecs:get(id, "transform")
        transform.rot, transform.scale = rot, scale
        ids[#ids + 1] = id
      end
    end
    return ids
  end

  return E
end

return entities
