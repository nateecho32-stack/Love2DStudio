-- Scene registry + stack with modal draw (whole stack renders bottom-up so
-- pause overlays draw over the live scene).
-- Adapted from Void Place engine/scene.lua.

local scene = {}
local stack = {}    -- entries: { name =, mod = }
local registry = {}

function scene.register(name, mod)
  assert(type(name) == "string" and type(mod) == "table", "scene.register(name, mod)")
  registry[name] = mod
end

function scene.top() local e = stack[#stack] return e and e.mod or nil end
function scene.topName() local e = stack[#stack] return e and e.name or nil end
function scene.depth() return #stack end

local function call(entry, method, ...)
  local mod = entry and entry.mod
  if mod and type(mod[method]) == "function" then
    return mod[method](...)
  end
end

function scene.push(name, args)
  local mod = registry[name]
  assert(mod, "scene not registered: " .. tostring(name))
  call(stack[#stack], "pause")
  stack[#stack + 1] = { name = name, mod = mod }
  call(stack[#stack], "enter", args)
end

function scene.pop()
  local entry = table.remove(stack)
  assert(entry, "scene stack is empty")
  call(entry, "exit")
  call(stack[#stack], "resume")
end

function scene.replace(name, args)
  local mod = registry[name]
  assert(mod, "scene not registered: " .. tostring(name))
  local entry = table.remove(stack)
  call(entry, "exit")
  stack[#stack + 1] = { name = name, mod = mod }
  call(stack[#stack], "enter", args)
end

function scene.update(dt) call(stack[#stack], "update", dt) end

function scene.draw()
  for i = 1, #stack do call(stack[i], "draw") end
end

function scene.keypressed(key, scancode, isrepeat) call(stack[#stack], "keypressed", key, scancode, isrepeat) end
function scene.mousepressed(x, y, button) call(stack[#stack], "mousepressed", x, y, button) end
function scene.mousereleased(x, y, button) call(stack[#stack], "mousereleased", x, y, button) end
function scene.mousemoved(x, y, dx, dy) call(stack[#stack], "mousemoved", x, y, dx, dy) end
function scene.wheelmoved(x, y) call(stack[#stack], "wheelmoved", x, y) end

function scene.resize(w, h)
  for i = 1, #stack do call(stack[i], "resize", w, h) end
end

function scene.clear()
  while #stack > 0 do scene.pop() end
end

return scene
