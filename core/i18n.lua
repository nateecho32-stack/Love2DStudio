-- Localization: locale registry, t(key) with an active -> en -> key fallback
-- chain, and format-arg interpolation. From 2d Trippy Hell i18n.lua.

local i18n = {}

function i18n.new(opts)
  opts = opts or {}
  local I = {
    locales = {},   -- id -> { name =, strings = { key = text } }
    active = opts.default or "en",
  }

  function I:registerLocale(id, def)
    def = def or {}
    def.strings = def.strings or {}
    self.locales[id] = def
  end

  function I:setLocale(id)
    if self.locales[id] then self.active = id end
  end

  function I:localeIds()
    local out = {}
    for id in pairs(self.locales) do out[#out + 1] = id end
    table.sort(out)
    return out
  end

  -- t("ui.play") -> string; format args interpolate via string.format when
  -- given; unknown keys fall back en -> the key itself (visible, debuggable)
  function I:t(key, ...)
    local entry = self.locales[self.active]
    local text = entry and entry.strings[key]
    if text == nil and self.active ~= "en" then
      text = self.locales.en and self.locales.en.strings[key]
    end
    if text == nil then return key end
    if select("#", ...) > 0 then return string.format(text, ...) end
    return text
  end

  return I
end

return i18n
