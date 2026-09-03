local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local ui = R("ui.init")

local function frame(U, mx, my, down, wheel)
  U:beginFrame(mx, my, down, wheel)
end

local function drawGuarded(U, fn)
  local ok, err = pcall(fn)
  if not ok then error("widget draw raised: " .. tostring(err), 2) end
  return ok
end

T.case("ui: focused button activates on confirm (keyboard/gamepad nav)", function()
  local U = ui.new{}
  U:beginFrame(-1, -1, false, 0, true) -- pointer off-screen, confirm edge
  local aClicked, bClicked = false, false
  drawGuarded(U, function()
    aClicked = U:button("a", 0, 0, 40, 20, "A") -- first registered = focused
    bClicked = U:button("b", 0, 30, 40, 20, "B")
  end)
  T.isTrue(aClicked, "focused button must fire on confirm")
  T.isTrue(not bClicked, "non-focused button must not fire")
end)

T.case("ui: focused toggle flips on confirm", function()
  local U = ui.new{}
  local v = false
  U:beginFrame(-1, -1, false, 0, false)
  drawGuarded(U, function() v = U:toggle("t", 0, 0, v, "on") end)
  T.isTrue(not v)
  U:beginFrame(-1, -1, false, 0, true)
  drawGuarded(U, function() v = U:toggle("t", 0, 0, v, "on") end)
  T.isTrue(v, "focused toggle must flip on confirm")
end)

T.case("ui: theme overrides merge over defaults", function()
  local U = ui.new{ theme = { accent = { 0, 1, 0 } } }
  T.eq(U.theme.accent, { 0, 1, 0 })
  T.eq(U.theme.text, { 1, 1, 1 })
end)

T.case("ui: button clicks on release inside", function()
  local U = ui.new{}
  frame(U, 10, 10, false)
  local clicked = false
  drawGuarded(U, function() clicked = U:button("b", 0, 0, 40, 20, "Go") end)
  T.isTrue(not clicked)
  frame(U, 10, 10, true) -- press inside
  drawGuarded(U, function() clicked = U:button("b", 0, 0, 40, 20, "Go") end)
  T.isTrue(not clicked)
  frame(U, 10, 10, false) -- release inside
  drawGuarded(U, function() clicked = U:button("b", 0, 0, 40, 20, "Go") end)
  T.isTrue(clicked)
end)

T.case("ui: release outside does not click; disabled ignores", function()
  local U = ui.new{}
  frame(U, 10, 10, true)
  drawGuarded(U, function() U:button("b", 0, 0, 40, 20, "Go") end)
  frame(U, 500, 500, false)
  local clicked
  drawGuarded(U, function() clicked = U:button("b", 0, 0, 40, 20, "Go") end)
  T.isTrue(not clicked)

  frame(U, 10, 10, false)
  drawGuarded(U, function() clicked = U:button("d", 0, 30, 40, 20, "No", { enabled = false }) end)
  T.isTrue(not clicked)
end)

T.case("ui: slider drags to the pointer", function()
  local U = ui.new{}
  frame(U, 50, 10, true)
  local v
  drawGuarded(U, function() v = U:slider("s", 0, 10, 100, 0) end)
  T.near(v, 0.5)
  frame(U, 0, 10, true)
  drawGuarded(U, function() v = U:slider("s", 0, 10, 100, v) end)
  T.near(v, 0)
end)

T.case("ui: toggle flips on click", function()
  local U = ui.new{}
  frame(U, 5, 5, false)
  local v = false
  drawGuarded(U, function() v = U:toggle("t", 0, 0, v, "on") end)
  T.isTrue(not v)
  frame(U, 5, 5, true)
  drawGuarded(U, function() v = U:toggle("t", 0, 0, v, "on") end)
  frame(U, 5, 5, false)
  drawGuarded(U, function() v = U:toggle("t", 0, 0, v, "on") end)
  T.isTrue(v)
end)

T.case("ui: list selects rows and scrolls", function()
  local U = ui.new{}
  local items = { "a", "b", "c", "d", "e", "f", "g" }
  frame(U, 10, 10, false, 0)
  local sel = 1
  drawGuarded(U, function() sel = U:list("l", 0, 0, 100, 96, items, sel, { rowH = 24 }) end)
  T.eq(sel, 1)
  frame(U, 10, 34, true) -- press row 2
  drawGuarded(U, function() sel = U:list("l", 0, 0, 100, 96, items, sel, { rowH = 24 }) end)
  frame(U, 10, 34, false) -- release
  drawGuarded(U, function() sel = U:list("l", 0, 0, 100, 96, items, sel, { rowH = 24 }) end)
  T.eq(sel, 2)
  frame(U, 10, 10, false, 1) -- wheel down scrolls
  drawGuarded(U, function() sel = U:list("l", 0, 0, 100, 96, items, sel, { rowH = 24 }) end)
  local state = U.widgetState["list:l"]
  T.eq(state.scroll, 1)
end)

T.case("ui: toasts age out and cap at 5", function()
  local U = ui.new{}
  for i = 1, 7 do U:toast("toast " .. i) end
  T.eq(#U.toasts, 5)
  T.eq(U.toasts[1].text, "toast 3") -- oldest dropped
  U:update(3)
  T.eq(#U.toasts, 0)
end)

T.case("ui: overlay stack routes to the top and pops", function()
  local U = ui.new{}
  U:pushOverlay("pause", { draw = function() end })
  U:pushOverlay("confirm", { draw = function() end })
  T.eq(U:topOverlay().name, "confirm")
  local popped = U:popOverlay()
  T.eq(popped.name, "confirm")
  T.eq(U:topOverlay().name, "pause")
end)

T.case("ui: focus order follows registration and wraps", function()
  local U = ui.new{}
  frame(U, -1, -1, false)
  drawGuarded(U, function()
    U:button("a", -100, -100, 10, 10, "A")
    U:button("b", -100, -100, 10, 10, "B")
    U:button("c", -100, -100, 10, 10, "C")
  end)
  T.eq(U:focusedId(), "a")
  U:moveFocus(1)
  T.eq(U:focusedId(), "b")
  U:moveFocus(1)
  U:moveFocus(1)
  T.eq(U:focusedId(), "a") -- wrapped
  U:moveFocus(-1)
  T.eq(U:focusedId(), "c")
end)
