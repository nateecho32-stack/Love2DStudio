-- Save thumbnail encoder: hands raw pixels to a one-shot LÖVE thread so PNG
-- encoding never blocks the frame. Single-shot pattern from 2d Trippy Hell
-- game/state/thumbnail_worker.lua ("no persistent loop, can never hang
-- shutdown").
local M = { _thread = nil, _errors = {} }

-- (dir creation lives with the caller: capture() ensures parents itself)

local WORKER_SRC = [[
local id = ...
local inbox = love.thread.getChannel(id)
local job = inbox:demand() -- single-shot: one job, then the thread dies
if job then
  local ok, err = pcall(function()
    local img = love.image.newImageData(job.w, job.h, "rgba8", job.pixels)
    img:encode("png", job.path)
  end)
  if not ok then love.thread.getChannel(id .. "_err"):push(tostring(err)) end
end
]]

function M._nextId()
  M._count = (M._count or 0) + 1
  return "studio_thumbnail_" .. M._count
end

-- nearest-neighbour downscale into a thumbnail-sized ImageData
function M.downscale(src, tw, th)
  tw, th = tw or 320, th or 180
  local sw, sh = src:getWidth(), src:getHeight()
  local out = love.image.newImageData(tw, th)
  for y = 0, th - 1 do
    local sy = math.min(sh - 1, math.floor((y + 0.5) * sh / th))
    for x = 0, tw - 1 do
      local sx = math.min(sw - 1, math.floor((x + 0.5) * sw / tw))
      out:setPixel(x, y, src:getPixel(sx, sy))
    end
  end
  return out
end

-- queue a thumbnail write; call M.poll() occasionally to surface thread errors
-- captureFn: love.graphics.captureScreenshot-style callback receiver
function M.capture(captureFn, path, w, h)
  if not (love and love.thread) then return false, "no threads" end
  captureFn(function(image)
    local ok, err = pcall(function()
      if love.filesystem then
        -- nested dirs (scenes/thumbs/) must exist before the thread writes
        local segments = {}
        for seg in path:gmatch("[^/\\]+") do segments[#segments + 1] = seg end
        local built = ""
        for i = 1, math.max(0, #segments - 1) do
          built = built .. segments[i]
          if not love.filesystem.getInfo(built) then love.filesystem.createDirectory(built) end
          built = built .. "/"
        end
      end
      local small = M.downscale(image, w or 320, h or 180)
      local id = M._nextId()
      local thread = love.thread.newThread(WORKER_SRC)
      thread:start(id)
      love.thread.getChannel(id):push({
        w = small:getWidth(),
        h = small:getHeight(),
        pixels = small:getString(),
        path = path,
      })
      M._thread = thread
    end)
    if not ok then M._errors[#M._errors + 1] = tostring(err) end
  end)
  return true
end

-- surfaces worker errors (call once per frame or per save)
function M.poll()
  local errs = M._errors
  M._errors = {}
  return errs
end

return M
