-- Spatial hash broadphase: insert/move/remove by id, rect queries.
-- Adapted from Void Place engine/grid.lua.

local grid = {}

function grid.new(cellSize)
  cellSize = cellSize or 64
  local G = { cellSize = cellSize, cells = {}, byId = {} }

  function G:_cellsFor(rec)
    local cs = self.cellSize
    local x0, y0 = math.floor(rec.x / cs), math.floor(rec.y / cs)
    local x1 = math.floor((rec.x + rec.w) / cs)
    local y1 = math.floor((rec.y + rec.h) / cs)
    local keys = {}
    for cy = y0, y1 do
      for cx = x0, x1 do
        keys[#keys + 1] = cx .. ":" .. cy
      end
    end
    return keys
  end

  function G:_index(id, rec)
    local cells = self:_cellsFor(rec)
    rec.cells = cells
    for i = 1, #cells do
      local cell = self.cells[cells[i]]
      if not cell then cell = {} self.cells[cells[i]] = cell end
      cell[id] = true
    end
  end

  function G:_unindex(rec)
    for i = 1, #rec.cells do
      local cell = self.cells[rec.cells[i]]
      if cell then cell[rec.id] = nil end
    end
  end

  function G:insert(id, x, y, w, h)
    assert(not self.byId[id], "grid: id already present: " .. tostring(id))
    local rec = { id = id, x = x, y = y, w = w or 0, h = h or 0 }
    self.byId[id] = rec
    self:_index(id, rec)
  end

  function G:move(id, x, y)
    local rec = self.byId[id]
    if not rec then return end
    self:_unindex(rec)
    rec.x, rec.y = x, y
    self:_index(id, rec)
  end

  function G:remove(id)
    local rec = self.byId[id]
    if not rec then return end
    self:_unindex(rec)
    self.byId[id] = nil
  end

  -- returns array of unique ids overlapping the rect
  function G:queryRect(x, y, w, h)
    local cs = self.cellSize
    local seen, out = {}, {}
    local x0, y0 = math.floor(x / cs), math.floor(y / cs)
    local x1 = math.floor((x + w) / cs)
    local y1 = math.floor((y + h) / cs)
    for cy = y0, y1 do
      for cx = x0, x1 do
        local cell = self.cells[cx .. ":" .. cy]
        if cell then
          for id in pairs(cell) do
            if not seen[id] then
              seen[id] = true
              out[#out + 1] = id
            end
          end
        end
      end
    end
    return out
  end

  return G
end

return grid
