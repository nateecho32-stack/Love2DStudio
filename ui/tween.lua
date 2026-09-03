-- Tween manager: fire-and-forget property animation. One-advance-per-frame
-- pattern from 2d Trippy Hell ui/common.lua; anchored Desired* tweening idea
-- from 20 Games MenuComponent.

local tween = {}

local function linear(t) return t end
local function smoothstep(t)
  t = math.min(1, math.max(0, t))
  return t * t * (3 - 2 * t)
end
local function easeOutCubic(t)
  t = t - 1
  return 1 + t * t * t
end

tween.ease = { linear = linear, smoothstep = smoothstep, easeOutCubic = easeOutCubic, easeInCubic = function(t) return t * t * t end }

function tween.new()
  local M = { active = {} }

  -- to(obj, {prop = targetValue, ...}, dur, {ease=, delay=, onDone=}) -> handle
  function M:to(obj, props, dur, opts)
    opts = opts or {}
    local tw = {
      obj = obj,
      dur = math.max(dur or 0.3, 1e-6),
      t = 0,
      delay = opts.delay or 0,
      ease = opts.ease or smoothstep,
      onDone = opts.onDone,
      props = {},
    }
    for k, target in pairs(props) do
      tw.props[k] = { from = obj[k], to = target }
    end
    self.active[#self.active + 1] = tw
    return tw
  end

  function M:cancel(handle) handle.dead = true end

  function M:update(dt)
    local active = self.active
    for i = #active, 1, -1 do
      local tw = active[i]
      if tw.dead then
        table.remove(active, i)
      else
        if tw.delay > 0 then tw.delay = tw.delay - dt end
        if tw.delay <= 0 then
          tw.t = tw.t + dt
          local k = math.min(1, tw.t / tw.dur)
          local e = tw.ease(k)
          for name, p in pairs(tw.props) do
            tw.obj[name] = p.from + (p.to - p.from) * e
          end
          if k >= 1 then
            table.remove(active, i)
            if tw.onDone then tw.onDone() end
          end
        end
      end
    end
  end

  function M:count() return #self.active end
  return M
end

-- module-level default instance
local default = tween.new()
function tween.to(obj, props, dur, opts) return default:to(obj, props, dur, opts) end
function tween.cancel(h) return default:cancel(h) end
function tween.update(dt) return default:update(dt) end
function tween.count() return default:count() end

return tween
