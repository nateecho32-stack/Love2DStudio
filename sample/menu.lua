-- Gem Haul menu: scene transitions, stats HUD, focus-navigated buttons.

local root = (...) and ((...):match("^(.-)sample%.") or "") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local S = R("init")
local sample = R("sample.init")

local scene = {}
local U, tweens

function scene.enter()
  U = S.ui.new{ font = S.assets.font(nil, 16) }
  tweens = S.tween.new()
  S.input.define({
    uiConfirm = { keys = { "return", "space" }, buttons = { "a" } },
    uiDown = { keys = { "down" }, buttons = { "dpdown" } },
    uiUp = { keys = { "up" }, buttons = { "dpup" } },
  })
  sample.checkMilestones(U)
end

function scene.update(dt)
  tweens:update(dt)
  U:update(dt)
  if S.input.pressed("uiDown") or S.input.pressed("uiUp") then U:moveFocus(1) end
end

function scene.draw()
  local w, h = love.graphics.getDimensions()
  love.graphics.clear(0.07, 0.08, 0.1)
  love.graphics.setColor(1, 0.75, 0.3)
  love.graphics.print("GEM HAUL", 40, 48, 0, 2, 2)
  love.graphics.setColor(1, 1, 1)
  local stats = sample.loadStats()
  love.graphics.print(string.format(
    "best %d | lifetime gems %d | runs %d (%d wins)",
    stats.bestScore, stats.totalGems, stats.runs, stats.wins), 44, 110)

  U:beginFrame(love.mouse.getPosition(), love.mouse.isDown(1), 0, S.input.pressed("uiConfirm"))
  if U:button("play", 44, 160, 180, 30, "Play (Enter)") then
    S.transitions.replace("gh_game", nil, { kind = "fade", dur = 0.35 })
    return
  end
  if U:button("quit", 44, 200, 180, 30, "Quit (Esc)") then
    love.event.quit()
  end
  U:drawToasts(44, 250)
end

function scene.keypressed(key)
  if key == "return" then
    S.transitions.replace("gh_game", nil, { kind = "fade", dur = 0.35 })
  elseif key == "escape" then
    love.event.quit()
  end
end

return scene
