-- Gem Haul results: outcome, score breakdown, best, milestone crossings,
-- and the transition back (or into the next run).

local root = (...) and ((...):match("^(.-)sample%.") or "") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local S = R("init")
local sample = R("sample.init")

local scene = {}
local U

function scene.enter()
  U = S.ui.new{ font = S.assets.font(nil, 15) }
  sample.checkMilestones(U)
end

function scene.update(dt)
  U:update(dt)
end

function scene.draw()
  local w, h = love.graphics.getDimensions()
  love.graphics.clear(0.07, 0.08, 0.1)
  local r = sample.lastResult or { win = false, score = 0, gems = 0, timeLeft = 0 }

  love.graphics.setColor(r.win and { 0.55, 1, 0.6 } or { 1, 0.5, 0.45 })
  love.graphics.print(sample.i18n:t(r.win and "results.win" or "results.lose"),
    40, 40, 0, 1.6, 1.6)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print(sample.i18n:t("results.score",
    r.score or 0, r.gems or 0, r.timeLeft or 0), 44, 96)
  local stats = sample.loadStats()
  if (r.score or 0) >= stats.bestScore and (r.score or 0) > 0 then
    love.graphics.setColor(1, 0.8, 0.3)
    love.graphics.print(sample.i18n:t("results.new_best"), 44, 120)
    love.graphics.setColor(1, 1, 1)
  end

  U:beginFrame(love.mouse.getPosition(), love.mouse.isDown(1), 0, S.input.pressed("uiConfirm"))
  if U:button("again", 44, 170, 180, 30, sample.i18n:t("results.again")) then
    S.transitions.replace("gh_game", nil, { kind = "fade", dur = 0.3 })
    return
  end
  if U:button("menu", 44, 210, 180, 30, sample.i18n:t("results.menu")) then
    S.transitions.replace("gh_menu", nil, { kind = "fade", dur = 0.3 })
    return
  end
  U:drawToasts(44, 260)
end

function scene.keypressed(key)
  if key == "return" then
    S.transitions.replace("gh_game", nil, { kind = "fade", dur = 0.3 })
  elseif key == "escape" then
    S.transitions.replace("gh_menu", nil, { kind = "fade", dur = 0.3 })
  end
end

return scene
