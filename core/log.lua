-- Leveled logger with a short in-memory history for crash reports.
-- Adapted from Void Place engine/log.lua.

local M = { level = "info", history = {} }

local LEVELS = { debug = 1, info = 2, warn = 3, error = 4 }
local MAX_HISTORY = 200

function M.setLevel(level)
  assert(LEVELS[level], "unknown log level: " .. tostring(level))
  M.level = level
end

local function write(level, fmt, ...)
  if LEVELS[level] < LEVELS[M.level] then return end
  local msg = select("#", ...) > 0 and string.format(fmt, ...) or fmt
  print(string.format("[%s] %s", level, msg))
  local h = M.history
  h[#h + 1] = level .. " " .. msg
  if #h > MAX_HISTORY then table.remove(h, 1) end
end

function M.debug(fmt, ...) write("debug", fmt, ...) end
function M.info(fmt, ...) write("info", fmt, ...) end
function M.warn(fmt, ...) write("warn", fmt, ...) end
function M.error(fmt, ...) write("error", fmt, ...) end

function M.dump() return table.concat(M.history, "\n") end
function M.clear() M.history = {} end

return M
