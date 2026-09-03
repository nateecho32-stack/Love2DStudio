-- Filesystem extras: LÖVE 11's love.filesystem.write silently FAILS on
-- nested paths unless every parent directory already exists. Every writer
-- that can receive a multi-segment path goes through here.

local fsx = {}

-- creates each directory segment of path's parent ("a/b/c.txt" -> a, a/b)
function fsx.ensureParent(path)
  if not (love and love.filesystem) then return false end
  local segments = {}
  for seg in path:gmatch("[^/\\]+") do segments[#segments + 1] = seg end
  local built = ""
  for i = 1, math.max(0, #segments - 1) do
    built = built .. segments[i]
    if built ~= "" and not love.filesystem.getInfo(built) then
      love.filesystem.createDirectory(built)
    end
    built = built .. "/"
  end
  return true
end

-- write that always succeeds at nested paths (or reports why it didn't)
function fsx.write(path, body)
  fsx.ensureParent(path)
  return love.filesystem.write(path, body)
end

return fsx
