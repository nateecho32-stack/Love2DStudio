-- Deterministic-frame screenshot capture: step a scene with fixed dt for N
-- frames, save a PNG into the save directory, and quit. Driven by boot + main.
-- Adapted from Void Place tools/capture.lua.

local M = { active = false, quitting = false }

function M.start(sceneName, opts)
  opts = opts or {}
  M.sceneName = sceneName
  M.frames = opts.frames or 30
  M.frame = 0
  M.dt = 1 / 60
  M.path = opts.path or ("shot_" .. sceneName .. ".png")
  M.active = true
  M.quitting = false
end

function M.step()
  M.frame = M.frame + 1
  return M.dt
end

function M.done() return M.frame >= M.frames end

function M.maybeShoot()
  if not M.active or not M.done() then return end
  M.active = false
  if love and love.graphics and love.filesystem then
    love.graphics.captureScreenshot(function(image)
      local ok, err = pcall(function()
        love.filesystem.write(M.path, image:encode("png"))
      end)
      print(ok and ("capture: wrote " .. M.path) or ("capture failed: " .. tostring(err)))
    end)
  end
  M.quitting = true
end

return M
