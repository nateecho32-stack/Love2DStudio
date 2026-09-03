-- Editor model logic, kept pure (no love.*) so it tests headlessly:
-- undo/redo command stack, topmost-item picking, and grid snapping.

local model = {}

-- command = { label =, redo = fn, undo = fn }
function model.newCommandStack()
  local S = { undoStack = {}, redoStack = {} }
  function S:push(cmd)
    cmd:redo()
    self.undoStack[#self.undoStack + 1] = cmd
    self.redoStack = {}
  end
  function S:undo()
    local cmd = table.remove(self.undoStack)
    if not cmd then return nil end
    cmd:undo()
    self.redoStack[#self.redoStack + 1] = cmd
    return cmd
  end
  function S:redo()
    local cmd = table.remove(self.redoStack)
    if not cmd then return nil end
    cmd:redo()
    self.undoStack[#self.undoStack + 1] = cmd
    return cmd
  end
  function S:canUndo() return #self.undoStack > 0 end
  function S:canRedo() return #self.redoStack > 0 end
  -- undo-history panel support: labels + the current position (1..n), and a
  -- jump that undoes/redoes repeatedly to reach a position
  function S:labels()
    local out = {}
    for i = 1, #self.undoStack do out[i] = self.undoStack[i].label or "?" end
    return out, #self.undoStack
  end
  function S:jumpTo(position)
    while #self.undoStack > position and #self.undoStack > 0 do self:undo() end
    while #self.undoStack < position and #self.redoStack > 0 do self:redo() end
  end
  return S
end

-- topmost item (last in list) whose bounds contain the point; returns index
function model.pick(items, defs, x, y)
  for i = #items, 1, -1 do
    local item = items[i]
    local def = defs(item.type)
    local size = def and def.size or { w = 24, h = 24 }
    if x >= item.x - size.w / 2 and x < item.x + size.w / 2
      and y >= item.y - size.h / 2 and y < item.y + size.h / 2 then
      return i
    end
  end
  return nil
end

-- every item whose bounds contain the point (multi-select click)
function model.pickAll(items, defs, x, y)
  local out = {}
  for i = 1, #items do
    local item = items[i]
    local def = defs(item.type)
    local size = def and def.size or { w = 24, h = 24 }
    if x >= item.x - size.w / 2 and x < item.x + size.w / 2
      and y >= item.y - size.h / 2 and y < item.y + size.h / 2 then
      out[#out + 1] = i
    end
  end
  return out
end

-- every item intersecting the marquee rect (normalized); returns indices
function model.boxSelect(items, defs, x0, y0, x1, y1)
  local lx, ly = math.min(x0, x1), math.min(y0, y1)
  local hx, hy = math.max(x0, x1), math.max(y0, y1)
  local out = {}
  for i = 1, #items do
    local item = items[i]
    local def = defs(item.type)
    local size = def and def.size or { w = 24, h = 24 }
    if item.x + size.w / 2 > lx and item.x - size.w / 2 < hx
      and item.y + size.h / 2 > ly and item.y - size.h / 2 < hy then
      out[#out + 1] = i
    end
  end
  return out
end

-- deep-copy items for the clipboard (indices sorted ascending, copies carry
-- no index state)
function model.copyItems(items, indices)
  local out = {}
  for n = 1, #indices do
    local src = items[indices[n]]
    local copy = { type = src.type, x = src.x, y = src.y }
    if src.rot and src.rot ~= 0 then copy.rot = src.rot end
    if src.scale and src.scale ~= 1 then copy.scale = src.scale end
    local props = {}
    for k, v in pairs(src.props or {}) do
      props[k] = type(v) == "table" and model.deepCopy(v) or v
    end
    copy.props = props
    out[#out + 1] = copy
  end
  return out
end

function model.deepCopy(t)
  local out = {}
  for k, v in pairs(t) do
    out[k] = type(v) == "table" and model.deepCopy(v) or v
  end
  return out
end

-- tiny pure serializer for editor side-files (prefabs): strings, numbers,
-- booleans, nested tables. Not for save data — use save/serialize there.
function model.serializeTable(t, indent)
  indent = indent or ""
  local parts = { "{" }
  local inner = indent .. "  "
  local first = true
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  for _, k in ipairs(keys) do
    local v = t[k]
    if not first then parts[#parts + 1] = "," end
    first = false
    local key = type(k) == "string" and k:match("^[%a_][%w_]*$") and (k .. " = ") or ("[" .. string.format("%q", tostring(k)) .. "] = ")
    if type(v) == "table" then
      parts[#parts + 1] = "\n" .. inner .. key .. model.serializeTable(v, inner)
    elseif type(v) == "string" then
      parts[#parts + 1] = "\n" .. inner .. key .. string.format("%q", v)
    else
      parts[#parts + 1] = "\n" .. inner .. key .. tostring(v)
    end
  end
  parts[#parts + 1] = "\n" .. indent .. "}"
  return table.concat(parts)
end

function model.snap(value, step)
  if not step or step <= 0 then return value end
  return math.floor(value / step + 0.5) * step
end

return model
