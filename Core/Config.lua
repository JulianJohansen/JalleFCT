-- Core/Config.lua
-- SavedVariables management and defaults

local MCT = MidnightCombatText

local DEFAULTS = {
    enabled          = true,
    animStyle        = "classic",   -- "classic" | "modern"
    anchorMode       = "screen",    -- "screen" | "nameplate"
    anchorX          = 0,
    anchorY          = 200,
    nameplateOffsetX = 0,
    nameplateOffsetY = 40,
    mergeHits        = true,

    colors = {
        normal = { r = 0.92, g = 0.90, b = 0.85 },
        crit   = { r = 1.00, g = 0.82, b = 0.10 },
        dot    = { r = 0.85, g = 0.28, b = 0.28 },
        hot    = { r = 0.28, g = 0.82, b = 0.40 },
        miss   = { r = 0.55, g = 0.55, b = 0.55 },
        heal   = { r = 0.40, g = 0.90, b = 0.40 },
    },

    spellFilters = {},   -- [spellId] = bool  (true = show, false = hide)
    spellSizes   = {},   -- [spellId] = number (scale multiplier, default 1.0)
    spellMerge   = {},   -- [spellId] = bool  (true = merge hits, false = show each hit separately)
    knownSpells  = {},   -- [spellId] = spellName  (auto-populated from combat)
}

-- Deep-merge src into dst, skipping keys that already exist in dst
local function MergeDefaults(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            dst[k] = type(v) == "table" and CopyTable(v) or v
        elseif type(v) == "table" and type(dst[k]) == "table" then
            MergeDefaults(dst[k], v)
        end
    end
end

function MCT.Config.Init()
    if not MCT_Config then
        MCT_Config = {}
    end
    MergeDefaults(MCT_Config, DEFAULTS)
    MCT.db = MCT_Config
end

function MCT.Config.Set(key, value)
    MCT.db[key] = value
end

function MCT.Config.Get(key)
    return MCT.db[key]
end

-- Spell filter: nil treated as true (show by default)
function MCT.Config.GetSpellFilter(spellId)
    local v = MCT.db.spellFilters[spellId]
    return v == nil or v == true
end

function MCT.Config.SetSpellFilter(spellId, shown)
    MCT.db.spellFilters[spellId] = shown
end

function MCT.Config.GetSpellSize(spellId)
    return MCT.db.spellSizes[spellId] or 1.0
end

function MCT.Config.SetSpellSize(spellId, scale)
    MCT.db.spellSizes[spellId] = scale
end

-- Per-spell merge: nil treated as true (merge by default when global merge is on)
function MCT.Config.GetSpellMerge(spellId)
    local v = MCT.db.spellMerge[spellId]
    return v == nil or v == true
end

function MCT.Config.SetSpellMerge(spellId, merge)
    MCT.db.spellMerge[spellId] = merge
end

-- Called when a spell is seen in combat or preloaded from ClassData
function MCT.Config.RegisterSpell(spellId, spellName)
    if not MCT.db.knownSpells[spellId] then
        MCT.db.knownSpells[spellId] = spellName
        -- Notify spell list UI to refresh if it's open
        if MCT.UI.RefreshSpellList then
            MCT.UI.RefreshSpellList()
        end
    end
end
