-- Core/Events.lua
-- UNIT_COMBAT with spell-tracking filter:
--   Only displays hits that correlate with a recent player spell cast.
--   Auto-attacks detected via PLAYER_ENTER_COMBAT/PLAYER_LEAVE_COMBAT.
--   This filters out other players' damage (they won't match our spell casts).
-- CLEU is blocked in WoW 12.0 Midnight — confirmed via IsEventRegistered.

local JFCT = JalleFCT

local ucFrame    = CreateFrame("Frame")     -- dedicated UNIT_COMBAT frame
local eventFrame = CreateFrame("Frame")     -- target change, nameplates, etc.

-- ---------------------------------------------------------------------------
-- UNIT_COMBAT miss types
-- ---------------------------------------------------------------------------

local UC_MISS = {
    BLOCK = true, DODGE = true, PARRY = true, MISS = true,
    IMMUNE = true, DEFLECT = true, REFLECT = true,
    RESIST = true, ABSORB = true, EVADE = true,
}

-- ---------------------------------------------------------------------------
-- Spell tracking + auto-attack detection
-- UNIT_SPELLCAST_SUCCEEDED fires for abilities (not auto-attacks).
-- PLAYER_ENTER_COMBAT fires when player starts auto-attacking.
-- Together they cover all player damage sources.
-- ---------------------------------------------------------------------------

local lastPlayerSpellId = nil
local lastPlayerSpellTime = 0
local SPELL_TRACK_WINDOW = 0.4  -- tight window to avoid matching other players' hits

local spellTrackFrame = CreateFrame("Frame")
pcall(function()
    spellTrackFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "pet")
end)
spellTrackFrame:SetScript("OnEvent", function(self, event, unit, castGUID, spellId)
    if event == "UNIT_SPELLCAST_SUCCEEDED" and (unit == "player" or unit == "pet") then
        lastPlayerSpellId = spellId
        lastPlayerSpellTime = GetTime()
        if spellId then
            local nameOk, spellName = pcall(C_Spell.GetSpellName, spellId)
            if nameOk and spellName then
                JFCT.Config.RegisterSpell(spellId, spellName)
            end
        end
    end
end)

local function GetLastPlayerSpellId()
    if lastPlayerSpellId and (GetTime() - lastPlayerSpellTime) <= SPELL_TRACK_WINDOW then
        return lastPlayerSpellId
    end
    return nil
end

-- Returns true if the player likely caused this hit
-- Only matches recent spell casts — auto-attacks are dropped to avoid
-- showing other players' damage (no way to distinguish in UNIT_COMBAT).
local function IsLikelyPlayerDamage()
    return GetLastPlayerSpellId() ~= nil
end

-- ---------------------------------------------------------------------------
-- Debug
-- ---------------------------------------------------------------------------

local debugMode = false
function JFCT.Events.ToggleDebug()
    debugMode = not debugMode
    print("|cff00ff00JalleFCT debug:|r " .. (debugMode and "ON" or "OFF"))
end

-- ---------------------------------------------------------------------------
-- UNIT_COMBAT handler
-- Only displays hits when IsLikelyPlayerDamage() is true.
-- This filters out other players' damage in group content.
-- ---------------------------------------------------------------------------

local function OnUnitCombat(unit, action, flagText, amount, schoolMask)
    if not JFCT.db or not JFCT.db.enabled then return end

    if unit ~= "target" then return end

    local plate
    local pOk, p = pcall(C_NamePlate.GetNamePlateForUnit, "target")
    if pOk and p then plate = p end

    local isCrit = (flagText == "CRITICAL")

    if action == "WOUND" then
        if not JFCT.db.showOutgoingDamage and JFCT.db.showOutgoingDamage ~= nil then return end

        if not IsLikelyPlayerDamage() then
            if debugMode then
                print("|cff00ff00JFCT UC dropped:|r not player damage")
            end
            return
        end

        local spellId = GetLastPlayerSpellId()
        local eventType = isCrit and "crit" or "normal"
        JFCT.Display.ShowHit({
            amount = amount, spellId = spellId, eventType = eventType,
            isCrit = isCrit, plate = plate,
        })

    elseif action == "HEAL" then
        if not JFCT.db.showHeals then return end
        if not IsLikelyPlayerDamage() then return end

        local spellId = GetLastPlayerSpellId()
        JFCT.Display.ShowHit({
            amount = amount, spellId = spellId, eventType = "heal",
            isCrit = isCrit, plate = plate,
        })

    elseif UC_MISS[action] then
        if not IsLikelyPlayerDamage() then return end
        JFCT.Display.ShowHit({
            amount = action, eventType = "miss", isCrit = false, plate = plate,
        })
    end
end

-- ---------------------------------------------------------------------------
-- Per-nameplate UNIT_COMBAT (non-target mobs)
-- Same IsLikelyPlayerDamage filter
-- ---------------------------------------------------------------------------

local plateFrames = {}
local platePool = {}

local function GetPlateEventFrame()
    local f = table.remove(platePool)
    if not f then f = CreateFrame("Frame") end
    return f
end

local function RecyclePlateEventFrame(f)
    f:UnregisterAllEvents()
    f:SetScript("OnEvent", nil)
    table.insert(platePool, f)
end

local function OnNameplateUnitCombat(unitToken, plate)
    return function(self, event, unit, action, flagText, amount, schoolMask)
        if event ~= "UNIT_COMBAT" then return end
        if unit ~= unitToken then return end

        -- Skip current target — main UC handler covers it
        local isTarget = false
        local tOk, tResult = pcall(UnitIsUnit, unitToken, "target")
        if tOk then isTarget = tResult end
        if isTarget then return end

        if not JFCT.db or not JFCT.db.enabled then return end
        if not IsLikelyPlayerDamage() then return end

        local curPlate = plate
        local pOk, freshPlate = pcall(C_NamePlate.GetNamePlateForUnit, unitToken)
        if pOk and freshPlate then curPlate = freshPlate end

        local isCrit = (flagText == "CRITICAL")

        if action == "WOUND" then
            if not JFCT.db.showOutgoingDamage and JFCT.db.showOutgoingDamage ~= nil then return end
            local spellId = GetLastPlayerSpellId()
            local eventType = isCrit and "crit" or "normal"
            JFCT.Display.ShowHit({
                amount = amount, spellId = spellId, eventType = eventType,
                isCrit = isCrit, plate = curPlate,
            })

        elseif action == "HEAL" then
            if not JFCT.db.showHeals then return end
            local spellId = GetLastPlayerSpellId()
            JFCT.Display.ShowHit({
                amount = amount, spellId = spellId, eventType = "heal",
                isCrit = isCrit, plate = curPlate,
            })

        elseif UC_MISS[action] then
            JFCT.Display.ShowHit({
                amount = action, eventType = "miss", isCrit = false, plate = curPlate,
            })
        end
    end
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------

function JFCT.Events.Init()
    -- UNIT_COMBAT on dedicated frame
    local ucOk = pcall(function()
        ucFrame:RegisterUnitEvent("UNIT_COMBAT", "player", "target")
    end)
    if not ucOk then
        pcall(function() ucFrame:RegisterEvent("UNIT_COMBAT") end)
    end
    ucFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "UNIT_COMBAT" then OnUnitCombat(...) end
    end)

    -- General events
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")

    eventFrame:SetScript("OnEvent", JFCT.Events.OnEvent)
end

function JFCT.Events.OnEvent(self, event, ...)
    if event == "PLAYER_TARGET_CHANGED" then
        pcall(function()
            ucFrame:RegisterUnitEvent("UNIT_COMBAT", "player", "target")
        end)

    elseif event == "NAME_PLATE_UNIT_ADDED" then
        JFCT.Events.OnPlateAdded(...)

    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        JFCT.Events.OnPlateRemoved(...)

    elseif event == "PLAYER_REGEN_DISABLED" then
        JFCT.TestMode.Stop()
    end
end

-- ---------------------------------------------------------------------------
-- Nameplate tracking
-- ---------------------------------------------------------------------------

function JFCT.Events.OnPlateAdded(unitToken)
    if plateFrames[unitToken] then return end

    local pOk, plate = pcall(C_NamePlate.GetNamePlateForUnit, unitToken)
    if not pOk or not plate then return end

    local f = GetPlateEventFrame()
    plateFrames[unitToken] = f

    local regOk = pcall(function()
        f:RegisterUnitEvent("UNIT_COMBAT", unitToken)
    end)

    if regOk then
        f:SetScript("OnEvent", OnNameplateUnitCombat(unitToken, plate))
    else
        RecyclePlateEventFrame(f)
        plateFrames[unitToken] = nil
    end
end

function JFCT.Events.OnPlateRemoved(unitToken)
    local pOk, plate = pcall(C_NamePlate.GetNamePlateForUnit, unitToken)
    if pOk and plate then
        JFCT.Display.OnPlateRemoved(plate)
    end

    local f = plateFrames[unitToken]
    if f then
        RecyclePlateEventFrame(f)
        plateFrames[unitToken] = nil
    end
end

-- Legacy
function JFCT.Events.GetTargetNameplate()
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, "target")
    if ok and plate and plate:IsShown() then
        return plate
    end
    return nil
end
