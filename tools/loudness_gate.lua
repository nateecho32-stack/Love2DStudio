-- Loudness gate for AI-generated SFX (fix.md #1 from 2d Trippy Hell: the
-- same prompt produced -20.7 dBFS and -4.2 dBFS takes). Measures peak and
-- RMS of decoded SoundData and fails clips quieter than the threshold —
-- run it during STAGING, before install, never after.
-- dBFS reference: full-scale square = 0 dBFS; a full-scale sine is -3.01.

local M = { thresholdDb = -12 }

local function toDb(v)
  if v <= 0 then return -999 end
  return 20 * math.log(v) / math.log(10)
end

-- data: SoundData (decoded via love.sound.newSoundData(path) by the caller)
-- returns ok, peakDb, rmsDb
function M.check(data, thresholdDb)
  thresholdDb = thresholdDb or M.thresholdDb
  local n = data:getSampleCount()
  local channels = data:getChannels()
  local peak = 0
  local sum = 0
  for i = 0, n - 1 do
    local l, r = data:getSample(i)
    l = math.abs(l)
    r = r and math.abs(r)
    if l > peak then peak = l end
    if r and r > peak then peak = r end
    local mono = r and (l + r) / 2 or l
    sum = sum + mono * mono
  end
  local peakDb = toDb(peak)
  local rmsDb = toDb(math.sqrt(sum / math.max(1, n)))
  local ok = peakDb >= thresholdDb
  return ok, peakDb, rmsDb
end

return M
