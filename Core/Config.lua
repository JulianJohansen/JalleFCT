-- Core/Config.lua
-- SavedVariables management, profile system, and personal best tracking

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
    personalBestFlash = true,

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
    spellMerge   = {},   -- [spellId] = bool  (true = merge hits)
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

-- Deep copy a table
local function DeepCopy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = DeepCopy(v)
    end
    return copy
end

-- ---------------------------------------------------------------------------
-- Migration: convert old flat JalleFCT_Config to new profile structure
-- ---------------------------------------------------------------------------

local function MigrateIfNeeded()
    local sv = JalleFCT_Config
    -- Already migrated if profiles table exists
    if sv.profiles then return end

    -- Old format: flat table with all settings directly in sv
    -- Extract shared data
    local knownSpells = sv.knownSpells or {}
    sv.knownSpells = nil

    -- Everything remaining is profile data
    local profileData = {}
    for k, v in pairs(sv) do
        profileData[k] = v
    end

    -- Wipe and rebuild as new structure
    for k in pairs(sv) do
        sv[k] = nil
    end

    sv.activeProfile = "Default"
    sv.profiles = { ["Default"] = profileData }
    sv.knownSpells = knownSpells
    sv.personalBests = {}
    sv.globalBest = { spellId = nil, amount = 0 }
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------

function JFCT.Config.Init()
    if not JalleFCT_Config then
        JalleFCT_Config = {}
    end

    MigrateIfNeeded()

    local sv = JalleFCT_Config

    -- Ensure top-level structure
    if not sv.profiles then sv.profiles = {} end
    if not sv.activeProfile then sv.activeProfile = "Default" end
    if not sv.profiles[sv.activeProfile] then
        sv.profiles[sv.activeProfile] = {}
    end
    if not sv.knownSpells then sv.knownSpells = {} end
    if not sv.personalBests then sv.personalBests = {} end
    if not sv.globalBest then sv.globalBest = { spellId = nil, amount = 0 } end

    -- Merge defaults into active profile
    MergeDefaults(sv.profiles[sv.activeProfile], DEFAULTS)

    -- JFCT.db points to the active profile (all existing code reads from this)
    JFCT.db = sv.profiles[sv.activeProfile]

    -- Convenience references for shared data
    JFCT.sv = sv
end

-- ---------------------------------------------------------------------------
-- Profile management
-- ---------------------------------------------------------------------------

function JFCT.Config.GetProfileNames()
    local names = {}
    for name in pairs(JFCT.sv.profiles) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

function JFCT.Config.GetActiveProfile()
    return JFCT.sv.activeProfile
end

function JFCT.Config.SwitchProfile(name)
    if not JFCT.sv.profiles[name] then return false end
    JFCT.sv.activeProfile = name
    MergeDefaults(JFCT.sv.profiles[name], DEFAULTS)
    JFCT.db = JFCT.sv.profiles[name]
    -- Refresh UI if open
    if JFCT.UI.Refresh then JFCT.UI.Refresh() end
    return true
end

function JFCT.Config.CreateProfile(name, copyFrom)
    if JFCT.sv.profiles[name] then return false end
    if copyFrom and JFCT.sv.profiles[copyFrom] then
        JFCT.sv.profiles[name] = DeepCopy(JFCT.sv.profiles[copyFrom])
    else
        JFCT.sv.profiles[name] = DeepCopy(DEFAULTS)
    end
    return true
end

function JFCT.Config.DeleteProfile(name)
    -- Can't delete the last profile
    local count = 0
    for _ in pairs(JFCT.sv.profiles) do count = count + 1 end
    if count <= 1 then return false end

    JFCT.sv.profiles[name] = nil

    -- If we deleted the active profile, switch to first available
    if JFCT.sv.activeProfile == name then
        local first = next(JFCT.sv.profiles)
        JFCT.Config.SwitchProfile(first)
    end
    return true
end

function JFCT.Config.RenameProfile(oldName, newName)
    if not JFCT.sv.profiles[oldName] then return false end
    if JFCT.sv.profiles[newName] then return false end
    JFCT.sv.profiles[newName] = JFCT.sv.profiles[oldName]
    JFCT.sv.profiles[oldName] = nil
    if JFCT.sv.activeProfile == oldName then
        JFCT.sv.activeProfile = newName
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Personal best tracking
-- ---------------------------------------------------------------------------

-- Returns: isPersonalBest, isGlobalBest
function JFCT.Config.CheckPersonalBest(spellId, amount)
    if not JFCT.db.personalBestFlash then return false, false end
    if not spellId then return false, false end

    -- Safe conversion (amount may be a secret value)
    local numAmount
    local cOk, cVal = pcall(function() return tonumber(tostring(amount)) end)
    if not cOk or not cVal then return false, false end
    numAmount = cVal

    local pb = JFCT.sv.personalBests
    local gb = JFCT.sv.globalBest

    local isPersonalBest = false
    local isGlobalBest = false

    if not pb[spellId] or numAmount > pb[spellId] then
        pb[spellId] = numAmount
        isPersonalBest = true
    end

    if numAmount > (gb.amount or 0) then
        gb.spellId = spellId
        gb.amount = numAmount
        isGlobalBest = true
    end

    return isPersonalBest, isGlobalBest
end

function JFCT.Config.ResetPersonalBests()
    JFCT.sv.personalBests = {}
    JFCT.sv.globalBest = { spellId = nil, amount = 0 }
    print("|cff00ff00JalleFCT:|r Personal bests reset.")
end

-- ---------------------------------------------------------------------------
-- Import / Export  (pure-Lua base64 + simple serializer)
-- ---------------------------------------------------------------------------

local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function Base64Encode(data)
    local out = {}
    local pad = ""
    local len = #data
    if len % 3 == 1 then
        data = data .. "\0\0"
        pad = "=="
    elseif len % 3 == 2 then
        data = data .. "\0"
        pad = "="
    end
    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2)
        local n = a * 65536 + b * 256 + c
        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64
        out[#out + 1] = b64chars:sub(c1 + 1, c1 + 1)
                     .. b64chars:sub(c2 + 1, c2 + 1)
                     .. b64chars:sub(c3 + 1, c3 + 1)
                     .. b64chars:sub(c4 + 1, c4 + 1)
    end
    local result = table.concat(out)
    if #pad > 0 then
        result = result:sub(1, #result - #pad) .. pad
    end
    return result
end

local b64lookup = {}
for i = 1, 64 do
    b64lookup[b64chars:sub(i, i)] = i - 1
end

local function Base64Decode(data)
    data = data:gsub("[^" .. b64chars .. "=]", "")
    local out = {}
    for i = 1, #data, 4 do
        local a = b64lookup[data:sub(i, i)] or 0
        local b = b64lookup[data:sub(i + 1, i + 1)] or 0
        local c = b64lookup[data:sub(i + 2, i + 2)] or 0
        local d = b64lookup[data:sub(i + 3, i + 3)] or 0
        local n = a * 262144 + b * 4096 + c * 64 + d
        out[#out + 1] = string.char(math.floor(n / 65536) % 256,
                                     math.floor(n / 256) % 256,
                                     n % 256)
    end
    local result = table.concat(out)
    -- Trim padding
    if data:sub(-2) == "==" then
        result = result:sub(1, -3)
    elseif data:sub(-1) == "=" then
        result = result:sub(1, -2)
    end
    return result
end

-- Simple recursive serializer (no loadstring needed for deserialize)
local function Serialize(val, depth)
    depth = depth or 0
    if depth > 20 then return "nil" end
    local t = type(val)
    if t == "number" then
        return tostring(val)
    elseif t == "string" then
        return string.format("%q", val)
    elseif t == "boolean" then
        return val and "true" or "false"
    elseif t == "table" then
        local parts = {}
        for k, v in pairs(val) do
            local key
            if type(k) == "number" then
                key = "[" .. k .. "]"
            elseif type(k) == "string" then
                key = "[" .. string.format("%q", k) .. "]"
            else
                key = "[" .. tostring(k) .. "]"
            end
            parts[#parts + 1] = key .. "=" .. Serialize(v, depth + 1)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "nil"
end

-- Simple recursive deserializer (safe, no loadstring)
local function Deserialize(str)
    local pos = 1

    local function skipWhitespace()
        while pos <= #str and str:sub(pos, pos):match("%s") do
            pos = pos + 1
        end
    end

    local function parseValue()
        skipWhitespace()
        if pos > #str then return nil end

        local ch = str:sub(pos, pos)

        -- String
        if ch == '"' then
            local startPos = pos
            pos = pos + 1
            local result = {}
            while pos <= #str do
                local c = str:sub(pos, pos)
                if c == '\\' then
                    pos = pos + 1
                    local esc = str:sub(pos, pos)
                    if esc == 'n' then result[#result + 1] = '\n'
                    elseif esc == 't' then result[#result + 1] = '\t'
                    elseif esc == '\\' then result[#result + 1] = '\\'
                    elseif esc == '"' then result[#result + 1] = '"'
                    else result[#result + 1] = esc end
                    pos = pos + 1
                elseif c == '"' then
                    pos = pos + 1
                    return table.concat(result)
                else
                    result[#result + 1] = c
                    pos = pos + 1
                end
            end
            return nil -- unterminated string
        end

        -- Table
        if ch == '{' then
            pos = pos + 1
            local tbl = {}
            skipWhitespace()
            while pos <= #str and str:sub(pos, pos) ~= '}' do
                skipWhitespace()
                -- Parse key
                if str:sub(pos, pos) == '[' then
                    pos = pos + 1
                    local key = parseValue()
                    skipWhitespace()
                    if str:sub(pos, pos) == ']' then pos = pos + 1 end
                    skipWhitespace()
                    if str:sub(pos, pos) == '=' then pos = pos + 1 end
                    local val = parseValue()
                    if key ~= nil then
                        tbl[key] = val
                    end
                end
                skipWhitespace()
                if str:sub(pos, pos) == ',' then pos = pos + 1 end
            end
            if pos <= #str then pos = pos + 1 end -- skip '}'
            return tbl
        end

        -- Number or keyword
        local word = str:match("^([%w%.%-]+)", pos)
        if word then
            pos = pos + #word
            if word == "true" then return true end
            if word == "false" then return false end
            if word == "nil" then return nil end
            return tonumber(word)
        end

        return nil
    end

    return parseValue()
end

function JFCT.Config.ExportProfile(name)
    name = name or JFCT.sv.activeProfile
    local profile = JFCT.sv.profiles[name]
    if not profile then return nil end
    local serialized = Serialize(profile)
    return Base64Encode(serialized)
end

function JFCT.Config.ImportProfile(name, encoded)
    local decoded = Base64Decode(encoded)
    if not decoded or #decoded == 0 then
        print("|cffff4444JalleFCT:|r Import failed — invalid data.")
        return false
    end
    local tbl = Deserialize(decoded)
    if type(tbl) ~= "table" then
        print("|cffff4444JalleFCT:|r Import failed — could not parse profile.")
        return false
    end
    -- Fill missing keys from defaults
    MergeDefaults(tbl, DEFAULTS)
    JFCT.sv.profiles[name] = tbl
    print("|cff00ff00JalleFCT:|r Profile '" .. name .. "' imported.")
    return true
end

-- ---------------------------------------------------------------------------
-- Settings accessors (unchanged API)
-- ---------------------------------------------------------------------------

function JFCT.Config.Set(key, value)
    JFCT.db[key] = value
end

function JFCT.Config.Get(key)
    return JFCT.db[key]
end

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

function JFCT.Config.GetSpellMerge(spellId)
    local v = JFCT.db.spellMerge[spellId]
    return v == nil or v == true
end

function JFCT.Config.SetSpellMerge(spellId, merge)
    JFCT.db.spellMerge[spellId] = merge
end

-- ---------------------------------------------------------------------------
-- Blizzard floating combat text CVars
-- ---------------------------------------------------------------------------

local FCT_DISPLAY_CVARS = {
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
    if JFCT.db.hideBlizzardFCT then
        pcall(SetCVar, "enableFloatingCombatText", "0")
        pcall(SetCVar, "floatingCombatTextFloatMode", "0")
    end
end

-- Called when a spell is seen in combat or preloaded from ClassData
-- knownSpells is shared across profiles
function JFCT.Config.RegisterSpell(spellId, spellName)
    if not JFCT.sv.knownSpells[spellId] then
        JFCT.sv.knownSpells[spellId] = spellName
        if JFCT.UI.RefreshSpellList then
            JFCT.UI.RefreshSpellList()
        end
    end
end
