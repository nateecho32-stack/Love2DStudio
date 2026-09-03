-- Culling helpers: cheap "entirely outside the view" tests against a view
-- rect (camera:getView()). Adapted from 2d Trippy Hell render/cull.lua.

local M = {}

function M.point(view, x, y)
  return x >= view.x and x <= view.x + view.w
    and y >= view.y and y <= view.y + view.h
end

function M.rect(view, x, y, w, h)
  return x < view.x + view.w and view.x < x + w
    and y < view.y + view.h and view.y < y + h
end

function M.circle(view, x, y, r)
  local cx = math.max(view.x, math.min(x, view.x + view.w))
  local cy = math.max(view.y, math.min(y, view.y + view.h))
  local dx, dy = x - cx, y - cy
  return dx * dx + dy * dy <= r * r
end

return M
