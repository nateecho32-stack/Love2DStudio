-- Lazy asset cache with a nil-return contract: a missing asset returns nil so
-- callers fall back to procedural drawing instead of crashing (revert bad art
-- by deleting one file). Adapted from Void Place engine/assets.lua and the
-- 2d Trippy Hell render/sprites fallback seam.

local M = { images = {}, fonts = {}, sounds = {} }

local logger -- optional; injected via setLogger to keep this module dependency-free
function M.setLogger(l) logger = l end

local deferred = {}
local active = false

-- run fn now if booted, else after boot (love.graphics is not ready at require time)
function M.onReady(fn)
  if active then fn() else deferred[#deferred + 1] = fn end
end

function M.ready()
  active = true
  for i = 1, #deferred do deferred[i]() end
  deferred = {}
end

local function cacheGet(cache, key, loadFn)
  local hit = cache[key]
  if hit ~= nil then return hit or nil end -- missing assets cached as false
  local ok, result = pcall(loadFn)
  if ok and result then
    cache[key] = result
    return result
  end
  if logger then logger.warn("assets: failed to load %s (%s)", key, tostring(result)) end
  cache[key] = false
  return nil
end

function M.image(path)
  return cacheGet(M.images, path, function() return love.graphics.newImage(path) end)
end

-- path may be nil for the default font
function M.font(path, size)
  size = size or 14
  local key = tostring(path) .. "#" .. size
  return cacheGet(M.fonts, key, function()
    if path then return love.graphics.newFont(path, size) end
    return love.graphics.newFont(size)
  end)
end

function M.sound(path, mode)
  mode = mode or "static"
  local key = path .. ":" .. mode
  return cacheGet(M.sounds, key, function() return love.audio.newSource(path, mode) end)
end

-- drop cached references (objects GC once nothing else holds them)
function M.clear()
  M.images, M.fonts, M.sounds = {}, {}, {}
end

-- release GPU/audio handles explicitly (use only when nothing still draws them)
function M.purge()
  for _, cache in ipairs({ M.images, M.fonts, M.sounds }) do
    for _, res in pairs(cache) do
      if type(res) == "userdata" and res.release then pcall(res.release, res) end
    end
  end
  M.clear()
end

return M
