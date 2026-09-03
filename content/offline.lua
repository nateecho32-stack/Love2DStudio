-- Offline catch-up: re-runs the REAL action loop with presentation muted,
-- action-capped and efficiency-scaled ("being away isn't strictly better
-- than playing"). Pattern from Endless Grind advanceSim + OFFLINE flag.

local offline = {}

-- opts: { maxActions = 4000, efficiency = 0.6, minSeconds = 30 }
-- stepFn(elapsedInGameSeconds) advances one action tick and returns the
-- seconds it consumed (the real per-action cadence).
-- returns report = { seconds =, actions =, capped = }
function offline.advance(seconds, opts, stepFn)
  opts = opts or {}
  seconds = math.max(0, seconds)
  local report = { seconds = seconds, actions = 0, capped = false }

  if seconds < (opts.minSeconds or 30) then return report end

  local scaled = seconds * (opts.efficiency or 0.6)
  local maxActions = opts.maxActions or 4000
  local elapsed = 0
  while elapsed < scaled and report.actions < maxActions do
    local consumed = stepFn(elapsed)
    if not consumed or consumed <= 0 then consumed = 1 end
    elapsed = elapsed + consumed
    report.actions = report.actions + 1
  end
  if elapsed < scaled or report.actions >= maxActions then
    report.capped = true
  end
  report.elapsed = elapsed
  return report
end

return offline
