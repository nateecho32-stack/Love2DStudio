-- Action-based input: keyboard + gamepad buttons/axes with deadzone,
-- per-frame pressed/released edges, injectable backend for headless tests.
-- Adapted from Void Place engine/input.lua.

local M = { deadzone = 0.25 }

local actions = {}  -- name -> { keys, buttons, axis, dir }
local order = {}    -- stable iteration order
local cur, prev = {}, {}
local backend

local function defaultBackend()
  if not (love and love.keyboard) then
    return {
      keyDown = function() return false end,
      gamepad = function() return nil end,
    }
  end
  return {
    keyDown = function(_, key) return love.keyboard.isDown(key) end,
    gamepad = function()
      if not love.joystick then return nil end
      local pads = love.joystick.getJoysticks() or {}
      for i = 1, #pads do
        if pads[i]:isGamepad() then
          local j = pads[i]
          return {
            isDown = function(_, b) return j:isGamepadDown(b) end,
            axis = function(_, a) return j:getGamepadAxis(a) or 0 end,
          }
        end
      end
      return nil
    end,
  }
end

-- backend interface: :keyDown(key) -> bool, :gamepad() -> pad|nil
-- pad interface: :isDown(button) -> bool, :axis(name) -> -1..1
function M.setBackend(b) backend = b end

function M.getBackend()
  if not backend then backend = defaultBackend() end
  return backend
end

-- map: { jump = {keys={"space"}, buttons={"a"}},
--        moveX = {keys={"right"}, axis="leftx", dir=1}, ... }
function M.define(map)
  for name, def in pairs(map) do
    actions[name] = {
      keys = def.keys or {},
      buttons = def.buttons or {},
      axis = def.axis,
      dir = def.dir or 1,
    }
    if cur[name] == nil then
      order[#order + 1] = name
      cur[name], prev[name] = 0, 0
    end
  end
end

local function computeValue(def, be)
  for i = 1, #def.keys do
    if be:keyDown(def.keys[i]) then return 1 end
  end
  local pad = be:gamepad()
  if pad then
    for i = 1, #def.buttons do
      if pad:isDown(def.buttons[i]) then return 1 end
    end
    if def.axis then
      local raw = pad:axis(def.axis) * def.dir
      if raw > M.deadzone then
        return math.min(1, (raw - M.deadzone) / (1 - M.deadzone))
      end
    end
  end
  return 0
end

function M.update()
  local be = M.getBackend()
  for i = 1, #order do
    local name = order[i]
    prev[name] = cur[name]
    cur[name] = computeValue(actions[name], be)
  end
end

function M.value(action) return cur[action] or 0 end
function M.down(action) return M.value(action) > 0.5 end
function M.pressed(action) return cur[action] > 0.5 and (prev[action] or 0) <= 0.5 end
function M.released(action) return cur[action] <= 0.5 and (prev[action] or 0) > 0.5 end

-- reverse lookup for hint text; returns the first action bound to key
function M.actionFromKey(key)
  for i = 1, #order do
    local keys = actions[order[i]].keys
    for k = 1, #keys do
      if keys[k] == key then return order[i] end
    end
  end
  return nil
end

function M.clear()
  actions, order, cur, prev, backend = {}, {}, {}, {}, nil
end

return M
