# tests/

One module per core module + `smoke_test.lua` (boots the demo scene and runs
120 update+draw frames, asserting finite state).

Run with `run-tests.bat` (all) or `FRAMEWORK_CHECK=tests.rng_test run-tests.bat`
(one module via tools/checks.lua).

Each file starts with the path idiom so it works standalone and embedded:

```lua
local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
```

New test files are discovered automatically — no list to maintain.
