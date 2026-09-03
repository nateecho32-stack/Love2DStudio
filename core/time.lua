-- Clock: time scale, pause, real/game dt split, optional fixed-step accumulator
-- with spiral-of-death guard and interpolation alpha.
-- Adapted from Void Place engine/time.lua.

local M = {
  scale = 1,
  paused = false,
  fixedDt = nil,    -- set e.g. 1/60 to enable fixed stepping
  maxDt = 0.1,      -- clamp for stalls (window drag, alt-tab, debugger pause)
  maxFrame = 0.25,  -- spiral-of-death guard: max simulated time per frame
  realDt = 0,
  gameDt = 0,
  alpha = 0,        -- leftover fraction of a fixed step, for render interpolation
}

local acc = 0

-- stepFn, when given, is called once with gameDt (variable mode) or once per
-- fixed step (fixed mode). Returns gameDt. realDt stays raw so hitch/profiling
-- code can still see the stall.
function M.update(dt, stepFn)
  M.realDt = dt
  if M.paused then
    M.gameDt = 0
    M.alpha = 0
    return 0
  end
  local sdt = dt
  if sdt > M.maxDt then sdt = M.maxDt end
  M.gameDt = sdt * M.scale
  if not M.fixedDt then
    if stepFn then stepFn(M.gameDt) end
    return M.gameDt
  end
  acc = acc + M.gameDt
  if acc > M.maxFrame then acc = M.maxFrame end
  while acc >= M.fixedDt do
    acc = acc - M.fixedDt
    if stepFn then stepFn(M.fixedDt) end
  end
  M.alpha = acc / M.fixedDt
  return M.gameDt
end

function M.setFixed(dt) M.fixedDt = dt acc = 0 end
function M.setScale(s) M.scale = s end
function M.setPaused(p)
  if M.paused == p then return end
  M.paused = p
  acc = 0
end
function M.togglePause() M.setPaused(not M.paused) end

return M
