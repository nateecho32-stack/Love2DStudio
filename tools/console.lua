-- In-game dev console: backtick toggles, command registry, scrollback.
-- 20 Games GameConsole pattern (launch <id>, restart, volumes) + Trippy's
-- dev-suite ideas. main.lua routes textinput/keypressed here while open.

local console = {}

function console.new(opts)
  opts = opts or {}
  local C = {
    open = false,
    lines = {},          -- { text =, color = }
    input = "",
    maxLines = opts.maxLines or 12,
    commands = {},
    font = opts.font,
  }

  function C:register(name, help, fn)
    self.commands[name] = { help = help, fn = fn }
  end

  function C:log(text, color)
    self.lines[#self.lines + 1] = { text = text, color = color }
    if #self.lines > 60 then table.remove(self.lines, 1) end
  end

  function C:toggle()
    self.open = not self.open
    if self.open then self.input = "" end
  end

  -- returns true if the key was consumed. Space is handled by textinput,
  -- not here (LÖVE delivers both, and appending twice doubles spaces).
  function C:keypressed(key)
    if not self.open then return false end
    if key == "backquote" or key == "`" then
      self:toggle()
      return true
    elseif key == "escape" then
      self:toggle()
      return true
    elseif key == "return" or key == "kpenter" then
      local line = self.input
      self.input = ""
      self:log("> " .. line, { 0.7, 0.8, 1 })
      if line ~= "" then self:execute(line) end
      return true
    elseif key == "backspace" then
      self.input = self.input:sub(1, -2)
      return true
    end
    return true -- console open: swallow every key so scenes don't react
  end

  -- returns true if the character was consumed
  function C:textinput(text)
    if not self.open then return false end
    self.input = self.input .. text
    return true
  end

  function C:execute(line)
    local parts = {}
    for word in line:gmatch("%S+") do parts[#parts + 1] = word end
    local name = table.remove(parts, 1)
    local cmd = self.commands[name]
    if not cmd then
      self:log("unknown command: " .. name .. " (try help)", { 1, 0.5, 0.5 })
      return
    end
    local ok, result = pcall(cmd.fn, unpack(parts))
    if not ok then
      self:log("error: " .. tostring(result), { 1, 0.5, 0.5 })
    elseif result ~= nil then
      self:log(tostring(result))
    end
  end

  function C:draw(vp)
    if not self.open then return end
    if love and love.graphics then
      if self.font then love.graphics.setFont(self.font) end
      local winW, winH = love.graphics.getDimensions()
      local w = (vp and vp.width) or winW or 800
      local bottom = (vp and vp.height) or winH or 600
      local lineH = 16
      local h = lineH * (self.maxLines + 1) + 10
      local y = bottom - h
      love.graphics.setColor(0, 0, 0, 0.8)
      love.graphics.rectangle("fill", 0, y, w, h)
      love.graphics.setColor(1, 1, 1, 1)
      local first = math.max(1, #self.lines - self.maxLines + 1)
      for i = first, #self.lines do
        local line = self.lines[i]
        love.graphics.setColor(line.color or { 1, 1, 1 })
        love.graphics.print(line.text, 8, y + (i - first) * lineH + 4)
      end
      love.graphics.setColor(0.6, 0.9, 0.6)
      love.graphics.print("> " .. self.input .. "_", 8, y + h - lineH - 2)
      love.graphics.setColor(1, 1, 1, 1)
    end
  end

  return C
end

return console
