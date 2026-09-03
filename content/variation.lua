-- Variation engine: bounded-nudge mutation over a spec, dominance-weighted
-- breeding, curated wildcard injections, and scored rarity with procedural
-- self-labelling. Distilled from Vimur src/genome/ + the Python evolution sim.

local variation = {}

-- schema = { field = { kind = "number", spread = 0.2, min =, max =, int = } }
--          { field = { kind = "enum", values = {...}, default } }
--          { field = { kind = "boolean", default } }
function variation.new(opts)
  local V = { random = opts and opts.random or function() return love and love.math and love.math.random() or 0.5 end }
  local rng = V.random

  local function nudge(v, spec)
    local spread = spec.spread or 0.2
    local nv = v + (rng() * 2 - 1) * spread * math.max(1, math.abs(v))
    if spec.min then nv = math.max(spec.min, nv) end
    if spec.max then nv = math.min(spec.max, nv) end
    if spec.int then nv = math.floor(nv + 0.5) end
    return nv
  end

  -- opts: { rate = 0..1 chance per field, wildcards = { {weight=, apply=fn(spec, rng)} } }
  function V:mutate(spec, schema, opts)
    opts = opts or {}
    local rate = opts.rate or 0.5
    local log = {}
    for field, fspec in pairs(schema) do
      if rng() < rate then
        if fspec.kind == "number" then
          local before = spec[field] or fspec.default
          spec[field] = nudge(before, fspec)
          log[#log + 1] = field .. " " .. string.format("%.2f->%.2f", before, spec[field])
        elseif fspec.kind == "enum" then
          local values = fspec.values or {}
          spec[field] = values[math.max(1, math.ceil(rng() * #values))]
          log[#log + 1] = field .. "->" .. tostring(spec[field])
        elseif fspec.kind == "boolean" then
          spec[field] = not (spec[field] or fspec.default or false)
          log[#log + 1] = field .. " toggled"
        end
      end
    end
    -- curated wildcards: rare, hand-authored chaos (ALIEN_FRAGMENTS pattern)
    if opts.wildcards and rng() < (opts.wildcardChance or 0.1) then
      local pool = opts.wildcards
      local total = 0
      for i = 1, #pool do total = total + (pool[i].weight or 1) end
      local pick = rng() * total
      for i = 1, #pool do
        pick = pick - (pool[i].weight or 1)
        if pick <= 0 then
          pool[i].apply(spec, rng)
          log[#log + 1] = "WILDCARD: " .. (pool[i].name or "unknown")
          break
        end
      end
    end
    return spec, log
  end

  -- dominance = 0.5 +/- vigor difference, clamped; numbers blend, enums/bools coin-flip
  function V:breed(a, b, schema)
    local dominance = 0.5
    local child = {}
    for field, fspec in pairs(schema) do
      local av, bv = a[field], b[field]
      if fspec.kind == "number" then
        child[field] = av + (bv - av) * dominance + (rng() * 2 - 1) * ((fspec.spread or 0.2) * math.max(1, math.abs(av)) * 0.25)
        if fspec.min then child[field] = math.max(fspec.min, child[field]) end
        if fspec.max then child[field] = math.min(fspec.max, child[field]) end
        if fspec.int then child[field] = math.floor(child[field] + 0.5) end
      elseif fspec.kind == "boolean" then
        -- explicit branch: `and/or` breaks when the a-side value is false
        if rng() < dominance then child[field] = a[field] or false else child[field] = b[field] or false end
      else
        child[field] = (rng() < dominance) and av or bv
      end
    end
    return child
  end

  -- scored rarity: rubric = { { score = fn(spec) -> n } }, thresholds ascending
  function V:rarity(spec, rubric, thresholds)
    local score = 0
    for _, rule in ipairs(rubric) do score = score + rule(spec) end
    for i = #thresholds, 1, -1 do
      if score >= thresholds[i].at then return thresholds[i].name, score end
    end
    return thresholds[1] and thresholds[1].name or "common", score
  end

  return V
end

return variation
