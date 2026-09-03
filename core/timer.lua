-- Script timers on game time. Adapted from Vimur src/utils/timer.lua.

local Timer = {}
Timer.__index = Timer

local timer = {}

function timer.new() return setmetatable({ pending = {} }, Timer) end

-- module-level default instance for convenience
local default = timer.new()

function Timer:after(delay, fn)
  local h = { t = delay, fn = fn }
  self.pending[#self.pending + 1] = h
  return h
end

function Timer:every(interval, fn)
  local h = { t = interval, fn = fn, every = interval }
  self.pending[#self.pending + 1] = h
  return h
end

function Timer:cancel(h) h.dead = true end

function Timer:update(dt)
  local pending = self.pending
  -- backwards: callbacks may add timers (appends run next frame) or cancel
  for i = #pending, 1, -1 do
    local h = pending[i]
    if h.dead then
      table.remove(pending, i)
    else
      h.t = h.t - dt
      if h.t <= 0 then
        h.fn()
        if h.every then
          h.t = h.every
        else
          table.remove(pending, i)
        end
      end
    end
  end
end

function timer.after(delay, fn) return default:after(delay, fn) end
function timer.every(interval, fn) return default:every(interval, fn) end
function timer.cancel(h) return default:cancel(h) end
function timer.update(dt) return default:update(dt) end
function timer.clear() default.pending = {} end

return timer
