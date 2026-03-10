-- Core/Events.lua
-- Event registration and routing to Display
-- Primary source: UNIT_COMBAT (like MidnightBattleText)
-- Secondary: CLEU for spellId/crit data enrichment
-- Per-nameplate UNIT_COMBAT frames for multi-mob display

local JFCT = JalleFCT

local eventFrame = CreateFrame("Frame")

-- ---------------------------------------------------------------------------
-- UNIT_COMBAT miss types
-- ---------------------------------------------------------------------------

local UC_MISS = {
    BLOCK = true, DODGE = true, PARRY = true, MISS = true,
    IMMUNE = true, DEFLECT = true, REFLECT = true,
    RESIST = true, ABSORB = true, EVADE = true,
}

-- ---------------------------------------------------------------------------
-- CLEU sub-events (for enrichment / marking)
-- ---------------------------------------------------------------------------

local CLEU_DAMAGE = {
    SWING_DAMAGE = true, RANGE_DAMAGE = true, SPELL_DAMAGE = true,
    SPELL_PERIODIC_DAMAGE = true, DAMAGE_SHIELD = true,
}
local CLEU_HEAL = {
    SPELL_HEAL = true, SPELL_PERIODIC_HEAL = true,
}

-- ---------------------------------------------------------------------------
-- Spell tracking: UNIT_COMBAT doesn't provide spellId, so we capture
-- the last spell cast via UNIT_SPELLCAST_SUCCEEDED
-- ---------------------------------------------------------------------------

local lastPlayerSpellId = nil
local lastPlayerSpellTime = 0
local SPELL_TRACK_WINDOW = 1.5

local spellTrackFrame = CreateFrame("Frame")
pcall(function()
    spellTrackFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "pet")
end)
spellTrackFrame:SetScript("OnEvent", function(self, event, unit, castGUID, spellId)
    if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" then
        lastPlayerSpellId = spellId
        lastPlayerSpellTime = GetTime()

        -- Register spell name for spell list
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

-- ---------------------------------------------------------------------------
-- CLEU mark system: CLEU fires before UNIT_COMBAT on the same frame.
-- We mark player-source events with spellId/isCrit so UNIT_COMBAT can
-- use that data AND filter out other players' damage on our target.
-- ---------------------------------------------------------------------------

local recentCLEU = {}        -- [amount..category] = { time, spellId, isCrit, isPeriodic }
local DEDUP_WINDOW = 0.15
local cleuLastMark = 0
local CLEU_ACTIVE_WINDOW = 5

local function MarkCLEUEvent(amount, category, spellId, isCrit, isPeriodic)
    local now = GetTime()
    cleuLastMark = now
    local keyOk, key = pcall(function() return tostring(amount) .. category end)
    if not keyOk then return end
    recentCLEU[key] = { time = now, spellId = spellId, isCrit = isCrit, isPeriodic = isPeriodic }
end

-- Returns: marked, spellId, isCrit, isPeriodic.  Consumes the mark.
local function ConsumeCLEUMark(amount, category)
    local keyOk, key = pcall(function() return tostring(amount) .. category end)
    if not keyOk then return false, nil, false, false end
    local mark = recentCLEU[key]
    if mark and (GetTime() - mark.time) <= DEDUP_WINDOW then
        recentCLEU[key] = nil
        return true, mark.spellId, mark.isCrit, mark.isPeriodic
    end
    return false, nil, false, false
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
-- Shared: route a UNIT_COMBAT event to ShowHit with an optional plate
-- Args: plate (or nil), action, flagText, amount, schoolMask
-- ---------------------------------------------------------------------------

local function HandleCombatHit(plate, action, flagText, amount, schoolMask)
    if not JFCT.db or not JFCT.db.enabled then return end

    local isCrit = (flagText == "CRITICAL")

    if action == "WOUND" then
        if not JFCT.db.showOutgoingDamage and JFCT.db.showOutgoingDamage ~= nil then return end

        -- Check CLEU mark: only show if this was OUR damage
        local marked, cleuSpellId, cleuCrit, cleuPeriodic = ConsumeCLEUMark(amount, "damage")

        if marked then
            local spellId = cleuSpellId
            isCrit = cleuCrit or isCrit

            local eventType
            if cleuPeriodic then
                eventType = "dot"
            elseif isCrit then
                eventType = "crit"
            else
                eventType = "normal"
            end

            if eventType == "dot" and not JFCT.db.showDots then return end
            if spellId and not JFCT.Config.GetSpellFilter(spellId) then return end

            JFCT.Display.ShowHit({
                amount    = amount,
                spellId   = spellId,
                eventType = eventType,
                isCrit    = isCrit,
                plate     = plate,
            })
        else
            local spellId = GetLastPlayerSpellId()
            local timeSinceCast = lastPlayerSpellTime > 0 and (GetTime() - lastPlayerSpellTime) or 999
            local isDotLikely = (timeSinceCast > 0.4)

            if isDotLikely then
                if not JFCT.db.showDots then return end
                JFCT.Display.ShowHit({
                    amount    = amount,
                    spellId   = spellId,
                    eventType = "dot",
                    isCrit    = isCrit,
                    plate     = plate,
                })
            else
                local eventType = isCrit and "crit" or "normal"
                JFCT.Display.ShowHit({
                    amount    = amount,
                    spellId   = spellId,
                    eventType = eventType,
                    isCrit    = isCrit,
                    plate     = plate,
                })
            end
        end

    elseif action == "HEAL" then
        if not JFCT.db.showHeals then return end

        local marked, cleuSpellId, cleuCrit, cleuPeriodic = ConsumeCLEUMark(amount, "heal")
        if marked then
            local eventType = cleuPeriodic and "hot" or "heal"
            if eventType == "hot" and not JFCT.db.showHots then return end

            JFCT.Display.ShowHit({
                amount    = amount,
                spellId   = cleuSpellId,
                eventType = eventType,
                isCrit    = cleuCrit or isCrit,
                plate     = plate,
            })
        else
            local spellId = GetLastPlayerSpellId()
            local timeSinceCast = lastPlayerSpellTime > 0 and (GetTime() - lastPlayerSpellTime) or 999
            local isHotLikely = (timeSinceCast > 0.4)

            if isHotLikely then
                if not JFCT.db.showHots then return end
                JFCT.Display.ShowHit({
                    amount    = amount,
                    spellId   = spellId,
                    eventType = "hot",
                    isCrit    = isCrit,
                    plate     = plate,
                })
            else
                JFCT.Display.ShowHit({
                    amount    = amount,
                    spellId   = spellId,
                    eventType = "heal",
                    isCrit    = isCrit,
                    plate     = plate,
                })
            end
        end

    elseif UC_MISS[action] then
        JFCT.Display.ShowHit({
            amount    = action,
            eventType = "miss",
            isCrit    = false,
            plate     = plate,
        })
    end
end

-- ---------------------------------------------------------------------------
-- UNIT_COMBAT handler for main eventFrame (player + target)
-- ---------------------------------------------------------------------------

local function OnUnitCombat(unit, action, flagText, amount, schoolMask)
    if debugMode then
        print("|cff00ff00JFCT UC:|r unit=" .. tostring(unit) .. " action=" .. tostring(action)
              .. " flag=" .. tostring(flagText) .. " amount=" .. tostring(amount))
    end

    if unit == "target" then
        -- Get the target's nameplate (may be nil if nameplates are off)
        local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, "target")
        if not ok then plate = nil end
        HandleCombatHit(plate, action, flagText, amount, schoolMask)
    end
end

-- ---------------------------------------------------------------------------
-- Per-nameplate UNIT_COMBAT system
-- Each visible nameplate gets its own event frame that listens for
-- UNIT_COMBAT on that specific unit token (e.g. "nameplate3").
-- This lets us show damage on mobs that aren't our current target.
-- ---------------------------------------------------------------------------

local plateFrames = {}   -- [unitToken] = eventFrame
local platePool = {}     -- recycled frames

local function GetPlateEventFrame()
    local f = table.remove(platePool)
    if not f then
        f = CreateFrame("Frame")
    end
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
        -- unit should match our unitToken, but verify
        if unit ~= unitToken then return end

        if debugMode then
            print("|cff00ff00JFCT NP-UC:|r unit=" .. tostring(unit) .. " action=" .. tostring(action)
                  .. " flag=" .. tostring(flagText) .. " amount=" .. tostring(amount))
        end

        -- Refresh plate reference in case it changed
        local curPlate = plate
        local pOk, freshPlate = pcall(C_NamePlate.GetNamePlateForUnit, unitToken)
        if pOk and freshPlate then curPlate = freshPlate end

        HandleCombatHit(curPlate, action, flagText, amount, schoolMask)
    end
end

-- ---------------------------------------------------------------------------
-- CLEU handler (secondary — marks events for UNIT_COMBAT dedup/enrichment)
-- ---------------------------------------------------------------------------

local function TryParseCLEU()
    if not JFCT.db or not JFCT.db.enabled then return end

    local ok, err = pcall(function()
        local timestamp, subEvent, hideCaster,
              sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
              destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()

        local MINE = COMBATLOG_OBJECT_AFFILIATION_MINE or 0x1
        local isMySource = bit.band(sourceFlags, MINE) ~= 0
        if not isMySource then return end

        if CLEU_DAMAGE[subEvent] then
            local amount, spellId, critical
            if subEvent == "SWING_DAMAGE" then
                amount   = select(12, CombatLogGetCurrentEventInfo())
                critical = select(18, CombatLogGetCurrentEventInfo())
            else
                spellId  = select(12, CombatLogGetCurrentEventInfo())
                amount   = select(15, CombatLogGetCurrentEventInfo())
                critical = select(21, CombatLogGetCurrentEventInfo())
            end

            local isCrit = false
            if critical ~= nil then
                local cOk, cVal = pcall(function() return critical == true end)
                isCrit = cOk and cVal or false
            end

            local isPeriodic = (subEvent == "SPELL_PERIODIC_DAMAGE")

            -- Register spell
            if spellId then
                local nameOk, spellName = pcall(function()
                    return select(13, CombatLogGetCurrentEventInfo())
                end)
                if nameOk and spellName then
                    JFCT.Config.RegisterSpell(spellId, spellName)
                end
            end

            MarkCLEUEvent(amount, "damage", spellId, isCrit, isPeriodic)
            return
        end

        if CLEU_HEAL[subEvent] then
            local TYPE_PET = COMBATLOG_OBJECT_TYPE_PET or 0x1000
            local isPet = bit.band(sourceFlags, TYPE_PET) ~= 0
            if isPet then return end

            local spellId  = select(12, CombatLogGetCurrentEventInfo())
            local amount   = select(15, CombatLogGetCurrentEventInfo())
            local critical = select(21, CombatLogGetCurrentEventInfo())

            local isCrit = false
            if critical ~= nil then
                local cOk, cVal = pcall(function() return critical == true end)
                isCrit = cOk and cVal or false
            end

            local isPeriodic = (subEvent == "SPELL_PERIODIC_HEAL")
            MarkCLEUEvent(amount, "heal", spellId, isCrit, isPeriodic)
            return
        end
    end)

    if not ok and err and debugMode then
        print("|cffff4444JFCT CLEU error:|r " .. tostring(err))
    end
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------

function JFCT.Events.Init()
    -- Primary: UNIT_COMBAT for player + target
    local ucOk = pcall(function()
        eventFrame:RegisterUnitEvent("UNIT_COMBAT", "player", "target")
    end)
    if not ucOk then
        pcall(function() eventFrame:RegisterEvent("UNIT_COMBAT") end)
    end

    -- Secondary: CLEU for spell enrichment (register outside combat lockdown)
    if not InCombatLockdown() then
        pcall(function() eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED") end)
    end

    -- Re-register UNIT_COMBAT on target change
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")

    -- Nameplate tracking
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

    -- Stop test mode on combat
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    -- Retry CLEU after combat ends
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    eventFrame:SetScript("OnEvent", JFCT.Events.OnEvent)
end

function JFCT.Events.OnEvent(self, event, ...)
    if     event == "UNIT_COMBAT"                   then OnUnitCombat(...)
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED"   then TryParseCLEU()
    elseif event == "PLAYER_TARGET_CHANGED"         then
        pcall(function()
            eventFrame:RegisterUnitEvent("UNIT_COMBAT", "player", "target")
        end)
    elseif event == "NAME_PLATE_UNIT_ADDED"         then JFCT.Events.OnPlateAdded(...)
    elseif event == "NAME_PLATE_UNIT_REMOVED"       then JFCT.Events.OnPlateRemoved(...)
    elseif event == "PLAYER_REGEN_DISABLED"         then JFCT.TestMode.Stop()
    elseif event == "PLAYER_REGEN_ENABLED"          then
        pcall(function() eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED") end)
    end
end

-- ---------------------------------------------------------------------------
-- Nameplate tracking — each plate gets its own UNIT_COMBAT listener
-- ---------------------------------------------------------------------------

function JFCT.Events.OnPlateAdded(unitToken)
    -- Don't double-register
    if plateFrames[unitToken] then return end

    local pOk, plate = pcall(C_NamePlate.GetNamePlateForUnit, unitToken)
    if not pOk or not plate then return end

    local f = GetPlateEventFrame()
    plateFrames[unitToken] = f

    -- Register UNIT_COMBAT for this specific nameplate unit
    local regOk = pcall(function()
        f:RegisterUnitEvent("UNIT_COMBAT", unitToken)
    end)

    if regOk then
        f:SetScript("OnEvent", OnNameplateUnitCombat(unitToken, plate))
    else
        -- Registration failed, clean up
        RecyclePlateEventFrame(f)
        plateFrames[unitToken] = nil
    end
end

function JFCT.Events.OnPlateRemoved(unitToken)
    local f = plateFrames[unitToken]
    if f then
        RecyclePlateEventFrame(f)
        plateFrames[unitToken] = nil
    end
end

-- Legacy — kept for compatibility but no longer primary
function JFCT.Events.GetTargetNameplate()
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, "target")
    if ok and plate and plate:IsShown() then
        return plate
    end
    return nil
end
