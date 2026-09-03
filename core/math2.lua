-- Small 2D math helpers. Adapted from Void Place engine/math2.lua.

local M = {}

function M.clamp(v, lo, hi)
  if v < lo then return lo elseif v > hi then return hi end
  return v
end

function M.lerp(a, b, t) return a + (b - a) * t end

function M.approach(v, target, step)
  if v < target then return math.min(v + step, target) end
  return math.max(v - step, target)
end

function M.sign(v) return v > 0 and 1 or (v < 0 and -1 or 0) end

function M.dist2(x1, y1, x2, y2)
  local dx, dy = x2 - x1, y2 - y1
  return dx * dx + dy * dy
end

function M.dist(x1, y1, x2, y2) return math.sqrt(M.dist2(x1, y1, x2, y2)) end

function M.aabb(x1, y1, w1, h1, x2, y2, w2, h2)
  return x1 < x2 + w2 and x2 < x1 + w1 and y1 < y2 + h2 and y2 < y1 + h1
end

function M.pointInRect(px, py, x, y, w, h)
  return px >= x and px < x + w and py >= y and py < y + h
end

function M.smoothstep(t)
  t = M.clamp(t, 0, 1)
  return t * t * (3 - 2 * t)
end

function M.easeOutCubic(t) t = t - 1 return 1 + t * t * t end
function M.easeInCubic(t) return t * t * t end

function M.angleLerp(a, b, t)
  local d = (b - a) % (2 * math.pi)
  if d > math.pi then d = d - 2 * math.pi end
  return (a + d * t) % (2 * math.pi)
end

return M
