-- Audit mode: boot every registered scene, dwell N frames, screenshot each,
-- and write a PASS/FAIL report. The Love port of 20 Games' audit harness.
--
-- IMPORTANT: this is a STATEFUL PUMP, not a blocking call. Screenshots only
-- flush at the end of a real presented frame — an audit that runs and quits
-- inside love.load produces nothing. Call begin() once, then pump(dt) every
-- update until done.

local root = (...) and ((...):match("^(.-)tools%.") or "") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local fsx = R("core.fsx")

local audit = {}

local state = nil

-- opts: { S = studio api, scenes = {name = module}, frames = 90,
--         outDir = "audits/<ts>", quit = true }
function audit.begin(opts)
  assert(opts and opts.S and opts.scenes, "audit.begin needs {S=, scenes=}")
  local names = {}
  for name in pairs(opts.scenes) do names[#names + 1] = name end
  table.sort(names) -- deterministic order
  state = {
    S = opts.S,
    scenes = opts.scenes,
    names = names,
    next = 1,
    frame = 0,
    frames = opts.frames or 90,
    outDir = opts.outDir or ("audits/run_" .. os.date("%Y%m%d_%H%M%S")),
    results = {},
    flush = 0,
    quit = opts.quit ~= false,
    done = false,
  }
  state.S.log.info("audit: %d scenes, %d frames each", #names, state.frames)
  audit._pushNext()
  return state
end

function audit._pushNext()
  local st = state
  if st.next > #st.names then return false end
  local name = st.names[st.next]
  st.next = st.next + 1
  st.frame = 0
  st.current = name
  local ok, err = pcall(function()
    st.S.scene.clear()
    st.S.scene.register(name, st.scenes[name])
    st.S.scene.push(name)
    st.S.assets.ready()
  end)
  if not ok then
    st.results[#st.results + 1] = { scene = name, status = "FAIL", error = tostring(err) }
    st.S.log.error("audit: %s failed to boot: %s", name, tostring(err))
    return audit._pushNext() -- try the next scene
  end
  return true
end

function audit.active() return state ~= nil and not state.done end

-- one frame of the audit; call from love.update
function audit.pump(dt)
  local st = state
  if not st or st.done then return end
  st.frame = st.frame + 1
  local ok, err = pcall(function()
    st.S.input.update()
    st.S.scene.update(dt)
  end)
  if not ok then
    st.results[#st.results + 1] = { scene = st.current, status = "FAIL", error = tostring(err) }
    st.S.scene.clear()
    if not audit._pushNext() then audit._finish() end
    return
  end
  if st.frame >= st.frames then
    -- filename form: LÖVE writes it at the end of THIS presented frame
    -- (and, like every love.filesystem write, needs the parent to exist)
    fsx.ensureParent(st.outDir .. "/" .. st.current .. ".png")
    pcall(function()
      love.graphics.captureScreenshot(st.outDir .. "/" .. st.current .. ".png")
    end)
    st.results[#st.results + 1] = { scene = st.current, status = "PASS" }
    st.S.scene.clear()
    if not audit._pushNext() then audit._finish() end
  end
end

function audit._finish()
  local st = state
  st.done = true
  st.flush = 6 -- let the last screenshot's frame present before quitting
end

-- call after pump when done; returns true when the process may exit
function audit.settle()
  local st = state
  if not st or not st.done then return false end
  st.flush = st.flush - 1
  if st.flush > 0 then return false end

  local lines = {
    "# Audit report — " .. os.date("%Y-%m-%d %H:%M:%S"),
    "",
    "| scene | status | error |",
    "|---|---|---|",
  }
  local failed = 0
  for _, entry in ipairs(st.results) do
    lines[#lines + 1] = ("| %s | %s | %s |"):format(entry.scene, entry.status, entry.error or "")
    if entry.status == "FAIL" then failed = failed + 1 end
  end
  fsx.write(st.outDir .. "/report.md", table.concat(lines, "\n") .. "\n")
  st.S.log.info("audit complete: %s (%d failed)", st.outDir, failed)
  st.exitCode = failed
  if st.quit then love.event.quit(failed == 0 and 0 or 1) end
  return true
end

function audit.results() return state and state.results or {} end

return audit
