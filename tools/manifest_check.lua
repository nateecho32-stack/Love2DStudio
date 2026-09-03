-- Asset intent-manifest drift check: manifest -> disk (missing files) AND
-- disk -> manifest (orphans, the Burning 27-unreferenced-mp3s failure mode).
-- The manifest is hand-authored pure data; generated layout files are never
-- hand-edited (2d Trippy Hell render/sprites/manifest.lua convention).
--
-- manifest = { [semanticKey] = { src = "sprites/goblin.png" }, ... }
-- opts: { watchDir = "assets", listFn = fs.list, existsFn = fs.exists }
-- returns failures = { { kind = "missing"|"orphan", path = } }

local manifest_check = {}

function manifest_check.run(manifest, opts)
  opts = opts or {}
  local failures = {}
  local referenced = {}

  local function exists(path)
    if opts.existsFn then return opts.existsFn(path) end
    if love and love.filesystem then
      return love.filesystem.getInfo(path) ~= nil
    end
    return false
  end

  local function list(dir)
    if opts.listFn then return opts.listFn(dir) end
    if love and love.filesystem then return love.filesystem.getDirectoryItems(dir) end
    return {}
  end

  -- 1. every manifest entry must exist on disk
  for key, entry in pairs(manifest) do
    local src = entry and entry.src
    if not src then
      failures[#failures + 1] = { kind = "missing-src", path = key }
    elseif not exists(src) then
      failures[#failures + 1] = { kind = "missing", path = src, key = key }
    end
    if src then referenced[src] = true end
  end

  -- 2. every file under the watched dir must be referenced by the manifest
  local watchDir = opts.watchDir
  if watchDir then
    local ASSET_EXTS = { png = true, ogg = true, wav = true, mp3 = true, flac = true, jpg = true }
    local function walk(dir)
      for _, name in ipairs(list(dir)) do
        local path = dir .. "/" .. name
        if opts.isDirectory and opts.isDirectory(path) then
          walk(path)
        else
          local ext = name:match("%.(%w+)$")
          if ext and ASSET_EXTS[ext:lower()] and not referenced[path] then
            failures[#failures + 1] = { kind = "orphan", path = path }
          end
        end
      end
    end
    walk(watchDir)
  end

  table.sort(failures, function(a, b)
    if a.kind ~= b.kind then return a.kind < b.kind end
    return a.path < b.path
  end)
  return failures
end

return manifest_check
