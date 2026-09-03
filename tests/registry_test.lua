local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local registry = R("core.registry")

T.case("registry: register/get/has in insertion order", function()
  local R = registry.new()
  R:register("zeta", { n = 1 })
  R:register("alpha", { n = 2 })
  R:register("zeta", { n = 3 }) -- re-register updates, keeps order

  T.eq(R:get("zeta"), { n = 3 })
  T.isTrue(R:has("alpha"))
  T.eq(R:ids(), { "zeta", "alpha" })
  T.eq(R:count(), 2)

  local all = R:all()
  T.eq(all[1].id, "zeta")
  T.eq(all[1].def.n, 3)
  T.eq(all[2].id, "alpha")
end)

T.case("registry: unknown id returns nil (fallback seam, never raises)", function()
  local R = registry.new()
  T.isNil(R:get("ghost"))
  T.isTrue(not R:has("ghost"))
end)

T.case("registry: rejects bad registrations", function()
  local R = registry.new()
  T.fails(function() R:register(42, {}) end)
  T.fails(function() R:register("empty", nil) end)
end)
