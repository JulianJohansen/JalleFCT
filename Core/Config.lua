-- Core/Config.lua
-- SavedVariables management and defaults

local JFCT = JalleFCT

local DEFAULTS = {
    enabled          = true,
    animStyle        = "classic",   -- "classic" | "modern"
    anchorMode       = "screen",    -- "screen" | "nameplate"
    anchorX          = 0,
    anchorY          = 200,
    nameplateOffsetX = 0,
    nameplateOffsetY = 40,
    mergeHits        = true,
    hideBlizzardFCT  = true,
    showDots         = true,
    showHots         = true,
    showHeals        = true,

    -- Font
    font             = "Fonts\\FRIZQT__.TTF",
    fontSize         = 22,
    fontFlags        = "OUTLINE",     -- "NONE" | "OUTLINE" | "THICKOUTLINE" | "MONOCHROME"
    fontShadow       = false,
    fontShadowX      = 1,
    fontShadowY      = -1,

    -- Per-type font scale multipliers
    normalScale      = 1.0,
    critScale        = 1.25,
    dotScale         = 0.9,
    hotScale         = 0.9,
    healScale        = 1.0,
    missScale        = 0.8,

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

function JFCT.Config.Init()
    if not JalleFCT_Config then
        JalleFCT_Config = {}
    end
    MergeDefaults(JalleFCT_Config, DEFAULTS)
    JFCT.db = JalleFCT_Config
end

function JFCT.Config.Set(key, value)
    JFCT.db[key] = value
end

function JFCT.Config.Get(key)
    return JFCT.db[key]
end

-- Spell filter: nil treated as true (show by default)
function JFCT.Config.GetSpellFilter(spellId)
    local v = JFCT.db.spellFilters[spellId]
    return v == nil or v == true
end

function JFCT.Config.SetSpellFilter(spellId, shown)
    JFCT.db.spellFilters[spellId] = shown
end

function JFCT.Config.GetSpellSize(spellId)
    return JFCT.db.spellSizes[spellId] or 1.0
end

function JFCT.Config.SetSpellSize(spellId, scale)
    JFCT.db.spellSizes[spellId] = scale
end

-- Per-spell merge: nil treated as true (merge by default when global merge is on)
function JFCT.Config.GetSpellMerge(spellId)
    local v = JFCT.db.spellMerge[spellId]
    return v == nil or v == true
end

function JFCT.Config.SetSpellMerge(spellId, merge)
    JFCT.db.spellMerge[spellId] = merge
end

-- Blizzard floating combat text CVars
-- WoW 12.0 (Midnight) renamed many CVars with a _v2 suffix.
-- We try both old and new names via pcall so this works across versions.
local FCT_DISPLAY_CVARS = {
    -- Legacy names (pre-12.0)
    "floatingCombatTextCombatDamage",
    "floatingCombatTextCombatHealing",
    "floatingCombatTextCombatLogPeriodicSpells",
    "floatingCombatTextPetMeleeDamage",
    "floatingCombatTextPetSpellDamage",
    "floatingCombatTextDodgeParryMiss",
    "floatingCombatTextDamageReduction",
    "floatingCombatTextAuras",
    "floatingCombatTextHonorGains",
    "floatingCombatTextEnergyGains",
    "floatingCombatTextPeriodicEnergyGains",
    "floatingCombatTextReactives",
    "floatingCombatTextFriendlyHealers",
    "floatingCombatTextComboPoints",
    "floatingCombatTextLowManaHealth",
    "floatingCombatTextRepChanges",
    "floatingCombatTextCombatState",
    -- 12.0 Midnight _v2 names
    "floatingCombatTextCombatDamage_v2",
    "floatingCombatTextCombatHealing_v2",
    "floatingCombatTextCombatLogPeriodicSpells_v2",
    "floatingCombatTextPetMeleeDamage_v2",
    "floatingCombatTextPetSpellDamage_v2",
    "floatingCombatTextDodgeParryMiss_v2",
    "floatingCombatTextDamageReduction_v2",
    "floatingCombatTextAuras_v2",
    "floatingCombatTextHonorGains_v2",
    "floatingCombatTextEnergyGains_v2",
    "floatingCombatTextPeriodicEnergyGains_v2",
    "floatingCombatTextReactives_v2",
    "floatingCombatTextFriendlyHealers_v2",
    "floatingCombatTextComboPoints_v2",
    "floatingCombatTextLowManaHealth_v2",
    "floatingCombatTextRepChanges_v2",
    "floatingCombatTextCombatState_v2",
    "floatingCombatTextFloatMode_v2",
}

function JFCT.Config.UpdateBlizzardFCT()
    local val = JFCT.db.hideBlizzardFCT and "0" or "1"
    for _, cvar in ipairs(FCT_DISPLAY_CVARS) do
        pcall(SetCVar, cvar, val)
    end
    -- Also disable the master switch and floatMode with _v2
    if JFCT.db.hideBlizzardFCT then
        pcall(SetCVar, "enableFloatingCombatText", "0")
        pcall(SetCVar, "floatingCombatTextFloatMode", "0")
    end
end

-- Called when a spell is seen in combat or preloaded from ClassData
function JFCT.Config.RegisterSpell(spellId, spellName)
    if not JFCT.db.knownSpells[spellId] then
        JFCT.db.knownSpells[spellId] = spellName
        -- Notify spell list UI to refresh if it's open
        if JFCT.UI.RefreshSpellList then
            JFCT.UI.RefreshSpellList()
        end
    end
end
