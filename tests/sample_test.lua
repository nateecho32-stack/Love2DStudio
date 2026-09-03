-- Reference game verification: Gem Haul must be winnable and losable under
-- scripted input — the integration gate for Pass C (physics, triggers, loot,
-- fx, transitions, stats all in one loop).

local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local S = R("init")
local sample = R("sample.init")
local scene = R("core.scene")
local input = R("core.input")

local function fakeBackend()
  return {
    keys = {},
    keyDown = function(self, k) return self.keys[k] == true end,
    gamepad = function() return nil end,
  }
end

local function runGame(holdKey, maxFrames)
  sample.register()
  scene.clear()
  scene.push("gh_game", { layout = sample.DEFAULT_LAYOUT })
  local gameScene = scene.top()
  local be = fakeBackend()
  input.clear()
  input.setBackend(be)
  input.define({
    left = { keys = { "left", "a" } }, right = { keys = { "right", "d" } },
    up = { keys = { "up", "w" } }, down = { keys = { "down", "s" } },
  })
  input.update()
  if holdKey then be.keys[holdKey] = true end

  local lastState
  for _ = 1, maxFrames do
    input.update()
    scene.update(1 / 60)
    lastState = gameScene.hooks.state()
    if lastState.finished then break end
  end
  -- let the results transition finish popping
  for _ = 1, 40 do scene.update(1 / 60) end
  return lastState, scene.topName()
end

-- stats isolation: point the game's save at an in-memory fs so suite runs
-- and manual play never contaminate each other
local function fakeFs()
  local files = {}
  return {
    read = function(path) return files[path] end,
    write = function(path, body) files[path] = body return true end,
    remove = function(path) files[path] = nil return true end,
    list = function(dir)
      local out = {}
      for path in pairs(files) do
        local name = path:match("^" .. dir .. "/(.+)$")
        if name then out[#out + 1] = name end
      end
      return out
    end,
  }
end

T.case("gem haul: scripted run collects gems and exits (WIN)", function()
  if not (love and love.physics) then return end
  sample.save._fs = fakeFs()
  sample.ladder = nil
  local state, top = runGame("right", 900)
  T.isTrue(state.finished, "run must terminate")
  T.eq(state.gems, 3, "all gems collected on the hold-right line")
  T.isTrue(state.hearts > 0, "the chaser never catches a running player")
  T.isTrue(sample.lastResult.win, "reaching the exit with all gems is a win")
  T.isTrue(sample.lastResult.score > 0)
  T.eq(top, "gh_results", "results scene must be on top after the fade")
  scene.clear()
end)

T.case("gem haul: standing still lets the chaser drain hearts (LOSE)", function()
  if not (love and love.physics) then return end
  local state = runGame(nil, 1200)
  T.isTrue(state.finished, "run must terminate")
  T.eq(state.hearts, 0)
  T.isTrue(not sample.lastResult.win)
  scene.clear()
end)

T.case("gem haul: stats persist across runs through sidecar saves", function()
  if not (love and love.physics) then return end
  local before = sample.loadStats()
  runGame("right", 900)
  local after = sample.loadStats()
  T.eq(after.runs, before.runs + 1)
  T.eq(after.totalGems, before.totalGems + 3)
  T.eq(after.wins, before.wins + 1)
  T.isTrue(after.bestScore >= before.bestScore)
  scene.clear()
end)
