-- The scene editor: scene-view viewport (pan/zoom/grid), multi-select with
-- marquee + move gizmos, archetype palette + drag-drop placement with ghost,
-- grid snapping, rotate/scale, copy/paste, duplicate/delete, undo/redo with
-- a history panel, schema-driven inspector (string props via textfield),
-- tile painting, prefab-from-selection, and save/open of scene files.
-- The editor edits plain item lists (the Pass 5 scene-data model); a runtime
-- ecs is only built when the scene is played.

local root = (...) and ((...):match("^(.-)editor%.") or "") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local model = R("editor.model")

local editor = {}

local TILE = 32
local TILESET = {
  { id = 1, name = "grass", color = { 0.25, 0.5, 0.28 } },
  { id = 2, name = "dirt",  color = { 0.45, 0.35, 0.24 } },
  { id = 3, name = "stone", color = { 0.42, 0.44, 0.5 } },
  { id = 4, name = "water", color = { 0.2, 0.35, 0.6 } },
}

-- opts: { scenePath =, archetypes = {id = def}, S = studio api, width =, height = }
function editor.new(opts)
  local S = assert(opts.S, "editor needs the studio api")
  local defs = opts.archetypes or {}
  local scenePath = opts.scenePath or "scenes/sandbox.lua"
  local PREFAB_FILE = "scenes/prefabs.lua"

  local scene = {}

  local R, U, cmds
  local items = {}
  local tiles = {}            -- ["cx,cy"] = tile id
  local prefabs = {}          -- name -> { base = type, props = {...} }
  local sceneName = "untitled"
  local tool = "select"       -- select | place | paint
  local placingType = nil
  local paintTile = 1
  local selection = {}        -- item index -> true
  local primary = nil         -- inspector anchor
  local drag = nil            -- group move gesture state
  local marquee = nil         -- { x0, y0, x1, y1 } in world space
  local pan = nil
  local snap = 8
  local showGrid = true
  local showTiles = true
  local paletteIndex = 1
  local hierarchyIndex = nil
  local dirty = false
  local clipboard = {}

  local function defsOf(id) return defs[id] end

  local function selectedIndices()
    local out = {}
    for i in pairs(selection) do out[#out + 1] = i end
    table.sort(out)
    return out
  end

  local function clearSelection()
    selection = {}
    primary = nil
    hierarchyIndex = nil
  end

  -- ------------------------------------------------------------ commands ----
  local function placeCommand(type, x, y, props, rot, scale)
    local item = { type = type, x = x, y = y, props = props or {}, rot = rot or 0, scale = scale or 1 }
    local def = defsOf(type)
    if not props and def and def.schema then
      for name, spec in pairs(def.schema) do item.props[name] = spec.default end
    end
    return {
      label = "place " .. type,
      redo = function()
        item.index = #items + 1
        items[#items + 1] = item
        clearSelection()
        selection[#items] = true
        primary = #items
      end,
      undo = function()
        table.remove(items, item.index or #items)
        clearSelection()
      end,
    }
  end

  local function deleteCommand(indices)
    local snapshot = {}
    for n = 1, #indices do
      local i = indices[n]
      snapshot[#snapshot + 1] = { index = i, item = items[i] }
    end
    table.sort(snapshot, function(a, b) return a.index < b.index end)
    return {
      label = "delete " .. #snapshot,
      redo = function()
        -- remove back-to-front so earlier indices stay valid
        for n = #snapshot, 1, -1 do table.remove(items, snapshot[n].index) end
        clearSelection()
      end,
      undo = function()
        for n = 1, #snapshot do
          table.insert(items, snapshot[n].index, snapshot[n].item)
        end
      end,
    }
  end

  local function moveCommand(moves)
    -- moves: { {index, fromX, fromY, toX, toY} }
    return {
      label = "move " .. #moves,
      redo = function()
        for _, m in ipairs(moves) do items[m.index].x, items[m.index].y = m.toX, m.toY end
      end,
      undo = function()
        for _, m in ipairs(moves) do items[m.index].x, items[m.index].y = m.fromX, m.fromY end
      end,
    }
  end

  local function transformCommand(indices, rotDelta, scaleMul)
    local snapshot = {}
    for n = 1, #indices do
      local i = indices[n]
      snapshot[#snapshot + 1] = { index = i, rot = items[i].rot or 0, scale = items[i].scale or 1 }
    end
    return {
      label = "transform " .. #snapshot,
      redo = function()
        for _, s in ipairs(snapshot) do
          local it = items[s.index]
          it.rot = s.rot + rotDelta
          it.scale = math.min(4, math.max(0.25, s.scale * scaleMul))
        end
      end,
      undo = function()
        for _, s in ipairs(snapshot) do
          items[s.index].rot, items[s.index].scale = s.rot, s.scale
        end
      end,
    }
  end

  local function pasteCommand(newItems)
    return {
      label = "paste " .. #newItems,
      redo = function()
        local base = #items
        for n = 1, #newItems do items[base + n] = newItems[n] end
        clearSelection()
        for n = 1, #newItems do selection[base + n] = true end
        primary = #items
      end,
      undo = function()
        for _ = 1, #newItems do table.remove(items) end
        clearSelection()
      end,
    }
  end

  local function tileCommand(key, fromId, toId)
    return {
      label = toId and ("tile " .. key) or ("erase " .. key),
      redo = function()
        if toId then tiles[key] = toId else tiles[key] = nil end
      end,
      undo = function()
        if fromId then tiles[key] = fromId else tiles[key] = nil end
      end,
    }
  end

  -- exposed for tests and UI (the ctrl+D path had a typo here once)
  function scene.duplicateSelection()
    local indices = selectedIndices()
    if #indices == 0 then return end
    local copies = {}
    for n = 1, #indices do
      local src = items[indices[n]]
      copies[#copies + 1] = {
        type = src.type, x = src.x + snap * 2, y = src.y + snap * 2,
        rot = src.rot or 0, scale = src.scale or 1,
        props = model.deepCopy(src.props or {}),
      }
    end
    cmds:push(pasteCommand(copies))
    dirty = true
  end

  -- panels own their screen rects; world clicks skip these areas
  local panels = {}

  local function inPanel(x, y)
    for i = 1, 8 do
      local p = panels[i]
      if p and x >= p.x and x < p.x + p.w and y >= p.y and y < p.y + p.h then return true end
    end
    return false
  end

  local function worldMouse()
    return R.viewport:getMouse()
  end

  local function countTiles()
    local n = 0
    for _ in pairs(tiles) do n = n + 1 end
    return n
  end

  local function tileKeyAt(wx, wy)
    local cx, cy = math.floor(wx / TILE), math.floor(wy / TILE)
    return cx .. "," .. cy, cx, cy
  end

  -- ------------------------------------------------------------ drawing ----
  local function drawTiles(view)
    if not showTiles then return end
    local cx0 = math.floor(view.x / TILE)
    local cy0 = math.floor(view.y / TILE)
    local cx1 = math.floor((view.x + view.w) / TILE)
    local cy1 = math.floor((view.y + view.h) / TILE)
    for cy = cy0, cy1 do
      for cx = cx0, cx1 do
        local id = tiles[cx .. "," .. cy]
        if id then
          local t = TILESET[id]
          if t then
            love.graphics.setColor(t.color[1], t.color[2], t.color[3], 0.85)
            love.graphics.rectangle("fill", cx * TILE, cy * TILE, TILE, TILE)
          end
        end
      end
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  local function drawWorld()
    local view = R.camera:getView()
    drawTiles(view)

    if showGrid then
      love.graphics.setColor(0.13, 0.14, 0.18)
      local step = snap > 0 and snap * 4 or TILE
      local gx0 = math.floor(view.x / step) * step
      local gy0 = math.floor(view.y / step) * step
      for gx = gx0, view.x + view.w + step, step do
        love.graphics.line(gx, view.y, gx, view.y + view.h)
      end
      for gy = gy0, view.y + view.h + step, step do
        love.graphics.line(view.x, gy, view.x + view.w, gy)
      end
      love.graphics.setColor(0.25, 0.2, 0.15)
      love.graphics.line(0, view.y, 0, view.y + view.h)
      love.graphics.line(view.x, 0, view.x + view.w, 0)
    end

    for i = 1, #items do
      local item = items[i]
      local def = defsOf(item.type) or {}
      local size = def.size or { w = 24, h = 24 }
      local tint = def.tint or { 0.5, 0.5, 0.55 }
      local s = item.scale or 1
      love.graphics.push()
      love.graphics.translate(item.x, item.y)
      love.graphics.rotate(item.rot or 0)
      love.graphics.setColor(tint[1], tint[2], tint[3], 1)
      love.graphics.rectangle("fill", -size.w / 2 * s, -size.h / 2 * s, size.w * s, size.h * s)
      love.graphics.pop()
      if selection[i] then
        love.graphics.setColor(primary == i and { 1, 0.85, 0.3 } or { 1, 1, 1 })
        love.graphics.setLineWidth(primary == i and 2 or 1)
        love.graphics.rectangle("line", item.x - size.w / 2 * s - 3, item.y - size.h / 2 * s - 3,
          size.w * s + 6, size.h * s + 6)
        love.graphics.setLineWidth(1)
      end
    end

    if marquee then
      love.graphics.setColor(0.6, 0.8, 1, 0.15)
      love.graphics.rectangle("fill",
        math.min(marquee.x0, marquee.x1), math.min(marquee.y0, marquee.y1),
        math.abs(marquee.x1 - marquee.x0), math.abs(marquee.y1 - marquee.y0))
      love.graphics.setColor(0.6, 0.8, 1, 0.8)
      love.graphics.rectangle("line",
        math.min(marquee.x0, marquee.x1), math.min(marquee.y0, marquee.y1),
        math.abs(marquee.x1 - marquee.x0), math.abs(marquee.y1 - marquee.y0))
    end

    if tool == "place" and placingType then
      local wx, wy = worldMouse()
      wx = model.snap(wx, snap)
      wy = model.snap(wy, snap)
      local def = defsOf(placingType) or { size = { w = 24, h = 24 } }
      love.graphics.setColor(0.6, 0.8, 1, 0.35)
      love.graphics.rectangle("fill", wx - def.size.w / 2, wy - def.size.h / 2, def.size.w, def.size.h)
      love.graphics.setColor(1, 1, 1, 0.7)
      love.graphics.rectangle("line", wx - def.size.w / 2, wy - def.size.h / 2, def.size.w, def.size.h)
    end

    if tool == "paint" then
      local wx, wy = worldMouse()
      local _, cx, cy = tileKeyAt(wx, wy)
      local t = TILESET[paintTile]
      love.graphics.setColor(t.color[1], t.color[2], t.color[3], 0.5)
      love.graphics.rectangle("fill", cx * TILE, cy * TILE, TILE, TILE)
      love.graphics.setColor(1, 1, 1, 0.8)
      love.graphics.rectangle("line", cx * TILE, cy * TILE, TILE, TILE)
    end
  end

  local function cycle(list, current)
    for i, v in ipairs(list) do
      if v == current then return list[i % #list + 1] end
    end
    return list[1]
  end

  local function drawHud()
    local vw, vh = R.viewport.width, R.viewport.height
    local mx, my = R.viewport:getMouse()
    local down = love.mouse.isDown(1)
    U:beginFrame(mx, my, down, 0)

    -- top toolbar
    panels[1] = { x = 0, y = 0, w = vw, h = 34 }
    U:panel(0, 0, vw, 34)
    local toolLabels = { select = "Select", place = "Place", paint = "Paint" }
    if U:button("tool", 8, 5, 96, 24, "Tool: " .. toolLabels[tool]) then
      tool = cycle({ "select", "place", "paint" }, tool)
      if tool == "place" and not placingType then
        local ids = {}
        for id in pairs(defs) do ids[#ids + 1] = id end
        table.sort(ids)
        placingType = ids[1]
        paletteIndex = 1
      end
    end
    if U:button("save", 110, 5, 62, 24, "Save") then
      scene.save()
    end
    if U:button("snap", 178, 5, 74, 24, "Snap " .. (snap > 0 and snap or "off")) then
      snap = snap >= 32 and 0 or snap * 2
    end
    if U:button("grid", 258, 5, 58, 24, showGrid and "Grid" or "No grid") then
      showGrid = not showGrid
    end
    if U:button("undo", 322, 5, 56, 24, "Undo", { enabled = cmds:canUndo() }) then
      cmds:undo()
    end
    if U:button("redo", 384, 5, 56, 24, "Redo", { enabled = cmds:canRedo() }) then
      cmds:redo()
    end
    if U:button("play", 446, 5, 64, 24, "Play F5") then
      scene.save()
      S.scene.push("play", { path = scenePath })
      return
    end
    if U:button("prefab", 516, 5, 96, 24, "Make Prefab") then
      scene.makePrefab()
    end

    -- scene name (textfield) top-right
    local nameValue, editing = U:textfield("sceneName", vw - 180, 5, 140, sceneName, { placeholder = "scene name" })
    if not editing and nameValue ~= "" and nameValue ~= sceneName then
      sceneName = nameValue
      dirty = true
    end

    -- left panel: palette (place) or tileset (paint)
    local ids = {}
    for id in pairs(defs) do ids[#ids + 1] = id end
    table.sort(ids)
    if tool == "place" then
      local labels = {}
      for i, id in ipairs(ids) do labels[i] = id end
      panels[2] = { x = 8, y = 44, w = 150, h = 40 + #labels * 26 }
      U:panel(8, 44, 150, 40 + #labels * 26)
      U:label(16, 50, "Palette")
      local chosen = U:list("palette", 16, 68, 134, 24 + #labels * 26, labels, paletteIndex, { rowH = 24 })
      if chosen ~= paletteIndex then
        paletteIndex = chosen
        placingType = ids[paletteIndex]
      end
    elseif tool == "paint" then
      local labels = {}
      for i, t in ipairs(TILESET) do labels[i] = t.name end
      panels[2] = { x = 8, y = 44, w = 150, h = 40 + #TILESET * 26 }
      U:panel(8, 44, 150, 40 + #TILESET * 26)
      U:label(16, 50, "Tileset")
      local chosen = U:list("tileset", 16, 68, 134, 24 + #TILESET * 26, labels, paintTile, { rowH = 24 })
      if chosen ~= paintTile then paintTile = chosen end
      U:label(16, 68 + #TILESET * 26 + 4, "LMB paint | RMB erase", { color = U.theme.dim })
    else
      panels[2] = nil
    end

    -- right: hierarchy
    local labels = {}
    for i = 1, #items do labels[i] = items[i].type .. " #" .. i end
    panels[3] = { x = vw - 168, y = 44, w = 160, h = 220 }
    U:panel(vw - 168, 44, 160, 220)
    U:label(vw - 160, 50, "Hierarchy")
    hierarchyIndex = U:list("hierarchy", vw - 160, 68, 144, 188, labels, hierarchyIndex, { rowH = 22 })
    if hierarchyIndex then
      if #selectedIndices() ~= 1 or not selection[hierarchyIndex] then
        clearSelection()
        selection[hierarchyIndex] = true
        primary = hierarchyIndex
      end
    end

    -- right: undo history
    panels[4] = { x = vw - 168, y = 272, w = 160, h = 170 }
    U:panel(vw - 168, 272, 160, 170)
    U:label(vw - 160, 278, "History")
    local histLabels, histCurrent = cmds:labels()
    if #histLabels > 0 then
      local chosen = U:list("history", vw - 160, 296, 144, 138, histLabels,
        histCurrent and histCurrent or 0, { rowH = 20 })
      if chosen and chosen ~= histCurrent then
        cmds:jumpTo(chosen)
      end
    end

    -- inspector bottom-right
    panels[5] = { x = vw - 268, y = vh - 214, w = 260, h = 206 }
    U:panel(vw - 268, vh - 214, 260, 206)
    U:label(vw - 260, vh - 208, "Inspector")
    local indices = selectedIndices()
    if #indices > 0 and items[primary or indices[1]] then
      local item = items[primary or indices[1]]
      local def = defsOf(item.type) or { schema = {} }
      U:label(vw - 260, vh - 192, item.type .. (#indices > 1 and (" +" .. (#indices - 1)) or ""),
        { color = U.theme.accent })
      local nameValue, nameEditing = U:textfield("itemName", vw - 260, vh - 178, 120,
        tostring(item.props.name or ""), { placeholder = "name" })
      if not nameEditing and nameValue ~= "" and nameValue ~= tostring(item.props.name or "") then
        item.props.name = nameValue
        dirty = true
      end
      U:label(vw - 260, vh - 154, string.format("x %.0f y %.0f rot %d scale %.2f",
        item.x, item.y, math.deg(item.rot or 0), item.scale or 1), { color = U.theme.dim })

      if #indices == 1 then
        local py = vh - 138
        for name, spec in pairs(def.schema or {}) do
          if py > vh - 40 then break end
          if spec.type == "number" then
            local range = (spec.max or spec.default or 1) - (spec.min or 0)
            local v = item.props[name] or spec.default or 0
            U:label(vw - 260, py, string.format("%s %.1f", name, v), { color = U.theme.dim })
            item.props[name] = (spec.min or 0)
              + U:slider("prop:" .. name, vw - 260, py + 14, 244, (v - (spec.min or 0)) / math.max(1, range)) * math.max(1, range)
            py = py + 34
          elseif spec.type == "boolean" then
            item.props[name] = U:toggle("prop:" .. name, vw - 260, py + 2, item.props[name] or false, name)
            py = py + 26
          elseif spec.type == "enum" then
            local values = spec.values or {}
            if U:button("prop:" .. name, vw - 260, py, 244, 22, name .. ": " .. tostring(item.props[name])) then
              local current = 1
              for i, v in ipairs(values) do if v == item.props[name] then current = i end end
              item.props[name] = values[current % #values + 1]
            end
            py = py + 28
          else -- string
            local nv, editingProp = U:textfield("prop:" .. name, vw - 260, py, 244, tostring(item.props[name] or spec.default or ""), { placeholder = name })
            if not editingProp and nv ~= tostring(item.props[name] or "") then
              item.props[name] = nv
            end
            py = py + 30
          end
        end
      else
        U:label(vw - 260, vh - 138, "multi-select: move/rotate/scale/delete act on all",
          { color = U.theme.dim })
      end
    else
      U:label(vw - 260, vh - 192, "nothing selected", { color = U.theme.dim })
    end

    U:label(vw - 8, 12, string.format("%s%s | %d entities %d tiles | %.1fx",
      sceneName, dirty and " *" or "", #items, countTiles(), R.camera.zoom),
      { align = "right", color = U.theme.dim })

    U:drawToasts(8, vh - 34)
  end

  -- ------------------------------------------------------------ lifecycle ----
  local function loadPrefabs()
    local body = love.filesystem.read(PREFAB_FILE)
    if not body then return end
    local ok, data = pcall(function()
      local chunk = load(body, "prefabs", "t") or load(body, "prefabs")
      return chunk and chunk() or nil
    end)
    if ok and type(data) == "table" then prefabs = data end
  end

  function scene.makePrefab()
    local indices = selectedIndices()
    if #indices == 0 or not items[primary or indices[1]] then
      U:toast("select an entity first", { color = U.theme.danger })
      return
    end
    local item = items[primary or indices[1]]
    local name = (item.props.name ~= nil and tostring(item.props.name) or nil) or (item.type .. "_" .. os.time() % 1000)
    prefabs[name] = { base = item.type, props = model.deepCopy(item.props or {}) }
    defs[name] = {
      label = "P: " .. name,
      size = (defsOf(item.type) or {}).size or { w = 24, h = 24 },
      tint = { 0.7, 0.6, 0.9 },
      schema = (defsOf(item.type) or {}).schema,
    }
    S.fsx.write(PREFAB_FILE,
      "-- GENERATED prefabs (Make Prefab in the editor)\nreturn " .. model.serializeTable(prefabs) .. "\n")
    U:toast("prefab '" .. name .. "' saved to palette")
  end

  local function scenedataOrEmpty()
    local loaded = S.scenedata.loadFromFile(scenePath)
    if loaded then return loaded end
    return { version = 1, name = "untitled", entities = {}, tiles = {} }
  end

  function scene.enter()
    R = S.render.new{ width = opts.width or 1280, height = opts.height or 720 }
    U = S.ui.new{ font = S.assets.font(nil, 13) }
    cmds = model.newCommandStack()
    items = {}
    tiles = {}
    prefabs = {}
    loadPrefabs()
    for name, pb in pairs(prefabs) do
      defs[name] = {
        label = "P: " .. name,
        size = (defsOf(pb.base) or {}).size or { w = 24, h = 24 },
        tint = { 0.7, 0.6, 0.9 },
        schema = (defsOf(pb.base) or {}).schema,
      }
    end

    local loaded = scenedataOrEmpty()
    items = loaded.entities or {}
    tiles = {}
    for key, id in pairs(loaded.tiles or {}) do tiles[key] = id end
    sceneName = loaded.name or "untitled"

    R.pipeline:addLayer("tiles+grid", drawWorld, 0)
    R.pipeline:addHud("editor", drawHud, 0)
    R:resize(love.graphics.getDimensions())
    scene._resetHandle = S.bus.on("graphics.reset", function()
      R:onGraphicsReset()
      R:resize(love.graphics.getDimensions())
    end)
    S.log.info("editor: %s (%d entities, %d tiles)", scenePath, #items, countTiles())
  end

  function scene.exit()
    if scene._resetHandle then S.bus.off(scene._resetHandle) scene._resetHandle = nil end
  end

  function scene.save()
    local entities = {}
    for i = 1, #items do
      local it = items[i]
      local entry = { type = it.type, x = it.x, y = it.y, props = it.props }
      if (it.rot or 0) ~= 0 then entry.rot = it.rot end
      if (it.scale or 1) ~= 1 then entry.scale = it.scale end
      entities[#entities + 1] = entry
    end
    local ok, err = S.scenedata.saveToFile(scenePath, {
      version = 1, name = sceneName, entities = entities, tiles = tiles,
    })
    dirty = not ok
    U:toast(ok and ("saved " .. scenePath) or ("save failed: " .. tostring(err)),
      { color = ok and U.theme.accent or U.theme.danger })
    if ok and love.graphics.captureScreenshot then
      S.thumbnail.capture(love.graphics.captureScreenshot,
        "scenes/thumbs/" .. (sceneName or "untitled") .. ".png")
    end
  end

  function scene.update(dt)
    U:update(dt)
    R.camera:update(dt)
    for _, err in ipairs(S.thumbnail.poll()) do
      U:toast("thumbnail failed: " .. tostring(err), { color = U.theme.danger })
    end
  end

  function scene.draw()
    R.pipeline:draw()
  end

  function scene.textinput(text)
    if U:textfieldEditing() then
      U:feedText(text)
    end
  end

  local function worldPos()
    local lx, ly = R.viewport:getMouse()
    return R.camera:toWorld(lx, ly)
  end

  -- ------------------------------------------------------------ input ----
  function scene.mousepressed(x, y, button)
    local lx, ly = R.viewport:toLogical(x, y)
    if inPanel(lx, ly) then return end
    local wx, wy = worldPos()

    if tool == "paint" then
      local key = tileKeyAt(wx, wy)
      if button == 1 then
        cmds:push(tileCommand(key, tiles[key], paintTile))
        dirty = true
      elseif button == 2 then
        if tiles[key] then
          cmds:push(tileCommand(key, tiles[key], nil))
          dirty = true
        end
      elseif button == 3 then
        pan = { sx = lx, sy = ly, cx = R.camera.x, cy = R.camera.y }
      end
      return
    end

    if button == 1 then
      if tool == "place" and placingType then
        local props = nil
        local pb = prefabs[placingType]
        if pb then props = model.deepCopy(pb.props) end
        cmds:push(placeCommand(placingType, model.snap(wx, snap), model.snap(wy, snap), props))
        dirty = true
      else
        local hit = model.pick(items, defsOf, wx, wy)
        local shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
        if hit then
          if shift then
            if selection[hit] then selection[hit] = nil else selection[hit] = true end
            primary = selection[hit] and hit or primary
          else
            clearSelection()
            selection[hit] = true
            primary = hit
          end
          hierarchyIndex = hit
          -- begin a group-move gesture
          local moves = {}
          for i in pairs(selection) do
            moves[#moves + 1] = { index = i, fromX = items[i].x, fromY = items[i].y }
          end
          drag = { moves = moves, dx = items[hit].x - wx, dy = items[hit].y - wy, moved = false }
        else
          if not shift then clearSelection() end
          marquee = { x0 = wx, y0 = wy, x1 = wx, y1 = wy }
        end
      end
    elseif button == 2 then
      if tool == "select" then
        local hit = model.pick(items, defsOf, wx, wy)
        if hit then
          selection[hit] = true
          cmds:push(deleteCommand(selectedIndices()))
          dirty = true
        end
      else
        pan = { sx = lx, sy = ly, cx = R.camera.x, cy = R.camera.y }
      end
    elseif button == 3 then
      pan = { sx = lx, sy = ly, cx = R.camera.x, cy = R.camera.y }
    end
  end

  function scene.mousereleased(x, y, button)
    if button == 1 and drag then
      if drag.moved then
        local moves = {}
        for _, m in ipairs(drag.moves) do
          local it = items[m.index]
          if it and (it.x ~= m.fromX or it.y ~= m.fromY) then
            moves[#moves + 1] = { index = m.index, fromX = m.fromX, fromY = m.fromY, toX = it.x, toY = it.y }
          end
        end
        if #moves > 0 then
          cmds:push(moveCommand(moves))
          dirty = true
        end
      end
      drag = nil
    end
    if button == 1 and marquee then
      if math.abs(marquee.x1 - marquee.x0) > 2 or math.abs(marquee.y1 - marquee.y0) > 2 then
        local hits = model.boxSelect(items, defsOf, marquee.x0, marquee.y0, marquee.x1, marquee.y1)
        for _, i in ipairs(hits) do
          selection[i] = true
          primary = i
        end
      end
      marquee = nil
    end
    if button == 2 or button == 3 then pan = nil end
  end

  function scene.mousemoved(x, y, dx, dy)
    local lx, ly = R.viewport:toLogical(x, y)
    if pan then
      local s = R.viewport:scale()
      R.camera.x = pan.cx - (lx - pan.sx) / s / R.camera.zoom
      R.camera.y = pan.cy - (ly - pan.sy) / s / R.camera.zoom
      return
    end
    if marquee then
      local wx, wy = worldPos()
      marquee.x1, marquee.y1 = wx, wy
      return
    end
    if drag then
      local wx, wy = worldPos()
      for _, m in ipairs(drag.moves) do
        local it = items[m.index]
        if it then
          it.x = model.snap(wx + drag.dx, snap)
          it.y = model.snap(wy + drag.dy, snap)
        end
      end
      drag.moved = true
    end
  end

  function scene.wheelmoved(_, y)
    -- zoom toward the mouse: keep the world point under the cursor fixed
    local lx, ly = R.viewport:getMouse()
    local wx, wy = R.camera:toWorld(lx, ly)
    R.camera:setZoom(R.camera.zoom * (y > 0 and 1.15 or 1 / 1.15))
    local nx, ny = R.camera:toWorld(lx, ly)
    R.camera.x = R.camera.x + (wx - nx)
    R.camera.y = R.camera.y + (wy - ny)
  end

  function scene.keypressed(key)
    if U:textfieldEditing() then
      if key == "return" or key == "kpenter" then
        U:endText(true)
      elseif key == "escape" then
        U:endText(false)
      elseif key == "backspace" then
        U:backspace()
      end
      return
    end
    local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
    if ctrl and key == "s" then
      scene.save()
    elseif ctrl and key == "z" then
      cmds:undo()
      dirty = true
    elseif ctrl and key == "y" then
      cmds:redo()
      dirty = true
    elseif ctrl and key == "c" then
      local indices = selectedIndices()
      if #indices > 0 then clipboard = model.copyItems(items, indices) end
    elseif ctrl and key == "v" then
      if #clipboard > 0 then
        local wx, wy = worldPos()
        local copies = {}
        for n = 1, #clipboard do
          local src = clipboard[n]
          copies[#copies + 1] = {
            type = src.type, x = model.snap(wx + (n - 1) * snap * 2, snap),
            y = model.snap(wy, snap), rot = src.rot or 0, scale = src.scale or 1,
            props = model.deepCopy(src.props or {}),
          }
        end
        cmds:push(pasteCommand(copies))
        dirty = true
      end
    elseif ctrl and key == "d" then
      scene.duplicateSelection()
    elseif ctrl and key == "a" then
      for i = 1, #items do selection[i] = true end
      primary = #items
    elseif key == "delete" or key == "backspace" then
      local indices = selectedIndices()
      if #indices > 0 then
        cmds:push(deleteCommand(indices))
        dirty = true
      end
    elseif key == "q" or key == "e" then
      local indices = selectedIndices()
      if #indices > 0 then
        cmds:push(transformCommand(indices, key == "q" and -math.pi / 12 or math.pi / 12, 1))
        dirty = true
      end
    elseif key == "[" or key == "]" then
      local indices = selectedIndices()
      if #indices > 0 then
        cmds:push(transformCommand(indices, 0, key == "[" and 0.8 or 1.25))
        dirty = true
      end
    elseif key == "tab" then
      tool = cycle({ "select", "place", "paint" }, tool)
      if tool == "place" and not placingType then
        local ids = {}
        for id in pairs(defs) do ids[#ids + 1] = id end
        table.sort(ids)
        placingType = ids[1]
        paletteIndex = 1
      end
    elseif key == "f" then
      R.camera:moveTo(0, 0)
      R.camera:setZoom(1)
    elseif key == "f5" then
      scene.save()
      S.scene.push("play", { path = scenePath })
    elseif key == "escape" then
      if S.scene.depth() > 1 then S.scene.pop() else love.event.quit() end
    end
  end

  function scene.resize(w, h)
    R:resize(w, h)
  end

  return scene
end

editor.model = model
return editor
