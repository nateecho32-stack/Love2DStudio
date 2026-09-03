-- UI kit: theme + immediate-mode widgets (button/panel/label/slider/toggle/
-- list), tooltip, toast queue, modal overlay stack, and gamepad-friendly
-- focus order. This is the layer every audited project was missing (all of
-- them hand-rolled bars, buttons and hit tests — the source of god-files).
-- Tooltip/toast patterns from Vimur; overlay routing from Trippy ui/.

local root = (...):match("^(.-)ui%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local tween = R("ui.tween")

local ui = {}
ui.tween = tween

local DEFAULT_THEME = {
  panelBg = { 0.1, 0.1, 0.13, 0.92 },
  panelBorder = { 0.28, 0.3, 0.36 },
  widgetBg = { 0.16, 0.17, 0.21 },
  text = { 1, 1, 1 },
  dim = { 0.6, 0.62, 0.66 },
  accent = { 0.95, 0.65, 0.25 },
  accentHover = { 1, 0.78, 0.45 },
  accentPress = { 0.78, 0.5, 0.15 },
  focus = { 1, 1, 1 },
  danger = { 0.9, 0.3, 0.3 },
  tooltipBg = { 0.04, 0.04, 0.07, 0.96 },
}

function ui.applyTheme(target, overrides)
  for k, v in pairs(DEFAULT_THEME) do target[k] = v end
  if overrides then
    for k, v in pairs(overrides) do target[k] = v end
  end
  return target
end

-- opts: { theme = {overrides}, font, width, height }
function ui.new(opts)
  opts = opts or {}
  local U = {
    theme = ui.applyTheme({}, opts.theme),
    font = opts.font,
    width = opts.width or 1280,
    height = opts.height or 720,
    mouse = { x = -1, y = -1, down = false, prevDown = false },
    wheel = 0,
    focusOrder = {},
    focusIndex = 0,
    overlays = {},
    toasts = {},
    _pressInside = {},
    widgetState = {},
  }

  local function inside(x, y, w, h)
    local m = U.mouse
    return m.x >= x and m.x < x + w and m.y >= y and m.y < y + h
  end

  local function pressedEdge() return U.mouse.down and not U.mouse.prevDown end
  local function releasedEdge() return not U.mouse.down and U.mouse.prevDown end

  local function setColor(c, a)
    love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * (a or 1))
  end

  -- per-frame: mouse position/button + wheel + confirm edge; clears per-frame
  -- focus order. confirm drives the FOCUSED widget (keyboard/gamepad nav).
  function U:beginFrame(mx, my, down, wheelY, confirm)
    self.mouse.prevDown = self.mouse.down
    self.mouse.x, self.mouse.y = mx or -1, my or -1
    self.mouse.down = down and true or false
    self.wheel = wheelY or 0
    self.confirm = confirm and true or false
    self.focusOrder = {}
  end

  function U:registerFocus(id)
    self.focusOrder[#self.focusOrder + 1] = id
    if not self.focusIndex or self.focusIndex < 1 then self.focusIndex = 1 end
  end

  function U:focusedId()
    return self.focusOrder[self.focusIndex]
  end

  -- dir = 1 (next) or -1 (previous); wraps
  function U:moveFocus(dir)
    local n = #self.focusOrder
    if n == 0 then return end
    self.focusIndex = ((self.focusIndex - 1 + dir) % n) + 1
  end

  local function isFocused(id, opts)
    if opts and opts.focused ~= nil then return opts.focused end
    return U:focusedId() == id
  end

  function U:panel(x, y, w, h, opts)
    opts = opts or {}
    setColor(opts.fill or self.theme.panelBg)
    love.graphics.rectangle("fill", x, y, w, h)
    if opts.border ~= false then
      setColor(opts.border or self.theme.panelBorder)
      love.graphics.setLineWidth(1)
      love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  function U:label(x, y, text, opts)
    opts = opts or {}
    if opts.font then love.graphics.setFont(opts.font) elseif self.font then love.graphics.setFont(self.font) end
    local color = opts.color or self.theme.text
    setColor(color)
    if opts.align == "center" then
      local w = love.graphics.getFont():getWidth(text)
      love.graphics.print(text, x - w / 2, y)
    elseif opts.align == "right" then
      local w = love.graphics.getFont():getWidth(text)
      love.graphics.print(text, x - w, y)
    else
      love.graphics.print(text, x, y)
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  -- returns clicked (released while inside)
  function U:button(id, x, y, w, h, label, opts)
    opts = opts or {}
    self:registerFocus(id)
    local hot = inside(x, y, w, h)
    local enabled = opts.enabled ~= false
    local key = "btn:" .. id
    local pressedInside = self._pressInside[key]
    if hot and pressedEdge() and enabled then self._pressInside[key] = true end
    if not U.mouse.down and self._pressInside[key] then self._pressInside[key] = nil end

    local c = self.theme.widgetBg
    if hot and enabled then c = self.theme.accentHover end
    if pressedInside and U.mouse.down then c = self.theme.accentPress end
    if opts.accent and not hot then c = self.theme.accent end
    setColor(c, enabled and 1 or 0.4)
    love.graphics.rectangle("fill", x, y, w, h)
    if isFocused(id, opts) then
      setColor(self.theme.focus)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", x - 2, y - 2, w + 4, h + 4)
    end
    self:label(x + w / 2, y + h / 2 - 7, label, { align = "center", color = enabled and self.theme.text or self.theme.dim })
    love.graphics.setColor(1, 1, 1, 1)
    local mouseClicked = enabled and hot and releasedEdge() and pressedInside ~= nil
    local focusClicked = enabled and isFocused(id, opts) and self.confirm
    return mouseClicked or focusClicked
  end

  -- returns new value (0..1); focused + left/right nudges
  function U:slider(id, x, y, w, value, opts)
    opts = opts or {}
    self:registerFocus(id)
    local h = opts.h or 12
    local hot = inside(x, y - 4, w, h + 8)
    if hot and pressedEdge() then self.widgetState["drag:" .. id] = true end
    if not U.mouse.down then self.widgetState["drag:" .. id] = nil end
    local dragging = self.widgetState["drag:" .. id]
    local newValue = value
    if dragging and U.mouse.down then
      newValue = math.min(1, math.max(0, (U.mouse.x - x) / w))
    end
    if isFocused(id, opts) then
      local nudge = 0
      if love and love.keyboard then
        if love.keyboard.isDown("left") then nudge = -0.02 end
        if love.keyboard.isDown("right") then nudge = 0.02 end
      end
      if nudge ~= 0 then
        newValue = math.min(1, math.max(0, newValue + nudge))
      end
    end
    -- draw
    setColor(self.theme.widgetBg)
    love.graphics.rectangle("fill", x, y, w, h)
    setColor(self.theme.accent)
    love.graphics.rectangle("fill", x, y, w * newValue, h)
    setColor(self.theme.text)
    love.graphics.circle("fill", x + w * newValue, y + h / 2, h / 2 + 3)
    love.graphics.setColor(1, 1, 1, 1)
    return newValue
  end

  -- returns new value (boolean); mouse click or focused+confirm flips it
  function U:toggle(id, x, y, value, label, opts)
    opts = opts or {}
    self:registerFocus(id)
    local w, h = 34, 16
    local hot = inside(x, y, w, h)
    local newValue = value
    if (hot and releasedEdge()) or (isFocused(id, opts) and self.confirm) then
      newValue = not value
    end
    setColor(newValue and self.theme.accent or self.theme.widgetBg)
    love.graphics.rectangle("fill", x, y, w, h, h / 2, h / 2)
    setColor(self.theme.text)
    local knobX = newValue and (x + w - h / 2 - 2) or (x + h / 2 + 2)
    love.graphics.circle("fill", knobX, y + h / 2, h / 2 - 2)
    if label then self:label(x + w + 8, y, label) end
    love.graphics.setColor(1, 1, 1, 1)
    return newValue
  end

  -- returns new selected index; wheel scrolls; focus + up/down moves
  function U:list(id, x, y, w, h, items, selected, opts)
    opts = opts or {}
    self:registerFocus(id)
    local rowH = opts.rowH or 24
    local state = self.widgetState["list:" .. id] or { scroll = 0 }
    self.widgetState["list:" .. id] = state
    local maxRows = math.floor(h / rowH)
    state.scroll = math.min(math.max(0, state.scroll), math.max(0, #items - maxRows))
    if inside(x, y, w, h) and self.wheel ~= 0 then
      state.scroll = math.min(math.max(0, state.scroll + (self.wheel > 0 and 1 or -1)), math.max(0, #items - maxRows))
    end
    if isFocused(id, opts) then
      if love and love.keyboard and pressedEdge() then
        if love.keyboard.isDown("up") then selected = math.max(1, selected - 1) end
        if love.keyboard.isDown("down") then selected = math.min(#items, selected + 1) end
      end
    end
    self:panel(x, y, w, h, opts)
    love.graphics.setScissor(x, y, w, h)
    for i = state.scroll + 1, math.min(#items, state.scroll + maxRows) do
      local ry = y + (i - state.scroll - 1) * rowH
      local hot = inside(x, ry, w, rowH)
      if i == selected then
        setColor(self.theme.accent, 0.35)
        love.graphics.rectangle("fill", x, ry, w, rowH)
      elseif hot then
        setColor(self.theme.widgetBg)
        love.graphics.rectangle("fill", x, ry, w, rowH)
      end
      if hot and pressedEdge() then selected = i end
      self:label(x + 8, ry + rowH / 2 - 7, tostring(items[i]), { color = i == selected and self.theme.accent or self.theme.text })
    end
    love.graphics.setScissor()
    love.graphics.setColor(1, 1, 1, 1)
    return selected
  end

  -- text field: click or focus+confirm to start editing; editing consumes
  -- textinput through U.feedText (the scene routes love.textinput to it);
  -- returns the (possibly updated) value. opts: {placeholder=, maxLen=}
  function U:textfield(id, x, y, w, value, opts)
    opts = opts or {}
    self:registerFocus(id)
    local h = 22
    local st = self.widgetState["tf:" .. id]
    local hot = inside(x, y, w, h)
    if not st or st.value ~= value then
      if st and st.editing and st.value ~= value then
        -- external change while not editing: resync
      end
      if not (st and st.editing) then
        self.widgetState["tf:" .. id] = { value = value, editing = false }
      end
      st = self.widgetState["tf:" .. id]
    end
    if (hot and releasedEdge()) or (isFocused(id, opts) and self.confirm and not st.editing) then
      st.editing = true
      st.value = value
      st.maxLen = opts.maxLen or 64
      self.activeTextfield = id
    end
    -- draw
    love.graphics.setColor(0.04, 0.04, 0.07, 0.9)
    love.graphics.rectangle("fill", x, y, w, h)
    if isFocused(id, opts) then
      love.graphics.setColor(self.theme.focus)
      love.graphics.setLineWidth(1.5)
      love.graphics.rectangle("line", x - 1.5, y - 1.5, w + 3, h + 3)
      love.graphics.setLineWidth(1)
    else
      love.graphics.setColor(self.theme.panelBorder)
      love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
    end
    local showText = st.editing and st.value or (value ~= "" and value or (opts.placeholder or ""))
    love.graphics.setColor(st.editing and self.theme.accent or (value == "" and self.theme.dim or self.theme.text))
    love.graphics.print(showText .. (st.editing and "_" or ""), x + 6, y + 4)
    love.graphics.setColor(1, 1, 1, 1)
    return st.editing and st.value or value, st.editing
  end

  -- route love.textinput here from the scene; returns true if consumed
  function U:feedText(text)
    local id = self.activeTextfield
    if not id then return false end
    local st = self.widgetState["tf:" .. id]
    if not st or not st.editing then return false end
    local maxLen = st.maxLen or 64
    if #st.value + #text <= maxLen then st.value = st.value .. text end
    return true
  end

  -- backspace into the active field (scenes route the key here)
  function U:backspace()
    local id = self.activeTextfield
    if not id then return end
    local st = self.widgetState["tf:" .. id]
    if st and st.editing then st.value = st.value:sub(1, -2) end
  end

  -- commit/cancel the active field (call on return/escape)
  function U:endText(commit)
    local id = self.activeTextfield
    if not id then return nil end
    local st = self.widgetState["tf:" .. id]
    self.activeTextfield = nil
    if not st then return nil end
    st.editing = false
    if commit == false then return nil end
    return st.value
  end

  function U:textfieldEditing()
    return self.activeTextfield ~= nil
  end

  -- draw near the mouse; call conditionally when a widget is hovered
  function U:tooltip(text)
    local x, y = self.mouse.x + 16, self.mouse.y + 12
    if love.graphics then
      if self.font then love.graphics.setFont(self.font) end
      local w = love.graphics.getFont():getWidth(text) + 12
      local h = love.graphics.getFont():getHeight() + 8
      if x + w > self.width then x = self.mouse.x - w - 12 end
      setColor(self.theme.tooltipBg)
      love.graphics.rectangle("fill", x, y, w, h)
      self:label(x + 6, y + 4, text)
    end
  end

  -- toasts: newest at the bottom, oldest dropped after max; aged in update
  function U:toast(text, opts)
    opts = opts or {}
    self.toasts[#self.toasts + 1] = { text = text, t = 0, ttl = opts.ttl or 3, color = opts.color or self.theme.accent }
    if #self.toasts > 5 then table.remove(self.toasts, 1) end
  end

  function U:drawToasts(x, y)
    for i = 1, #self.toasts do
      local toast = self.toasts[i]
      local a = math.min(1, toast.ttl - toast.t)
      self:panel(x, y + (i - 1) * 30, math.max(120, #toast.text * 9 + 24), 26, { fill = self.theme.tooltipBg, border = toast.color })
      setColor(toast.color, a)
      self:label(x + 10, y + (i - 1) * 30 + 6, toast.text, { color = self.theme.text })
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  function U:update(dt)
    for i = #self.toasts, 1, -1 do
      local toast = self.toasts[i]
      toast.t = toast.t + dt
      if toast.t >= toast.ttl then table.remove(self.toasts, i) end
    end
  end

  -- modal overlay stack: the top overlay captures input until popped
  function U:pushOverlay(name, handlers)
    self.overlays[#self.overlays + 1] = { name = name, handlers = handlers }
  end

  function U:popOverlay()
    return table.remove(self.overlays)
  end

  function U:topOverlay()
    return self.overlays[#self.overlays]
  end

  return U
end

return ui
