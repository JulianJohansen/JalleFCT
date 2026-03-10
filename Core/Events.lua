-- Core/Events.lua
-- Event registration and routing to CastTracker / Display

local JFCT = JalleFCT

local eventFrame = CreateFrame("Frame")

-- COMBAT_TEXT_UPDATE sub-types we care about
local DISPLAY_TYPES = {
    DAMAGE              = "normal",
    DAMAGE_CRIT         = "crit",
    SPELL_DAMAGE        = "normal",
    SPELL_DAMAGE_CRIT   = "crit",
    PERIODIC_DAMAGE     = "dot",
    HEAL                = "heal",
    HEAL_CRIT           = "heal",
    PERIODIC_HEAL       = "hot",
    PERIODIC_HEAL_CRIT  = "hot",
    MISS                = "miss",
    DODGE               = "miss",
    PARRY               = "miss",
    IMMUNE              = "miss",
    ABSORB              = "miss",
}

function JFCT.Events.Init()
    -- Primary display source: secret-safe, works in all content
    eventFrame:RegisterEvent("COMBAT_TEXT_UPDATE")

    -- Used for spell ID/name tracking (populates the spell filter list)
    -- Also provides correlation context for per-spell config
    eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

    -- Used for multi-hit grouping (dual-wield, cleave, etc.)
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "pet")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_START",     "player", "pet")

    -- Nameplate tracking for anchor mode
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

    -- Stop test mode if the player enters real combat
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")

    eventFrame:SetScript("OnEvent", JFCT.Events.OnEvent)
end

function JFCT.Events.OnEvent(self, event, ...)
    if     event == "COMBAT_TEXT_UPDATE"           then JFCT.Events.OnCombatText(...)
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED"  then JFCT.Events.OnCLEU()
    elseif event == "UNIT_SPELLCAST_START"         then JFCT.Events.OnSpellcastStart(...)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED"     then JFCT.Events.OnSpellcastSucceeded(...)
    elseif event == "NAME_PLATE_UNIT_ADDED"        then JFCT.Events.OnPlateAdded(...)
    elseif event == "NAME_PLATE_UNIT_REMOVED"      then JFCT.Events.OnPlateRemoved(...)
    elseif event == "PLAYER_REGEN_DISABLED"        then JFCT.TestMode.Stop()
    end
end

-- ---------------------------------------------------------------------------
-- COMBAT_TEXT_UPDATE  (primary display path, secret-safe)
-- ---------------------------------------------------------------------------

function JFCT.Events.OnCombatText(combatTextType)
    if not JFCT.db.enabled then return end

    local eventType = DISPLAY_TYPES[combatTextType]
    if not eventType then return end

    local amount = GetCurrentCombatTextEventInfo()
    if not amount then return end

    local isCrit = combatTextType:find("CRIT") ~= nil

    JFCT.CastTracker.OnCombatTextEvent(amount, eventType, isCrit)
end

-- ---------------------------------------------------------------------------
-- COMBAT_LOG_EVENT_UNFILTERED  (spell ID tracking + merge correlation)
-- ---------------------------------------------------------------------------

function JFCT.Events.OnCLEU()
    local _, subevent, _,
          sourceGUID, _, _, _,
          _, _, _, _,
          spellId, spellName = CombatLogGetCurrentEventInfo()

    -- Only care about the player and their pet as the source
    local playerGUID = UnitGUID("player")
    local petGUID    = UnitGUID("pet")
    if sourceGUID ~= playerGUID and sourceGUID ~= petGUID then return end

    if subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" then
        if spellId and spellName then
            JFCT.Config.RegisterSpell(spellId, spellName)
            JFCT.CastTracker.OnCLEUDamage(sourceGUID, spellId, spellName,
                subevent == "SPELL_PERIODIC_DAMAGE")
        end

    elseif subevent == "SWING_DAMAGE" then
        JFCT.Config.RegisterSpell(0, "Auto Attack")
        JFCT.CastTracker.OnCLEUDamage(sourceGUID, 0, "Auto Attack", false)
    end
end

-- ---------------------------------------------------------------------------
-- UNIT_SPELLCAST_START  (capture castBarID while cast is active)
-- ---------------------------------------------------------------------------

-- castBarID is available from UnitCastingInfo while UNIT_SPELLCAST_START fires
-- We cache it keyed by castGUID so we can retrieve it at SUCCEEDED
local pendingCastBarIDs = {}  -- [castGUID] = castBarID

function JFCT.Events.OnSpellcastStart(unitToken, castGUID, spellId)
    local _, _, _, _, _, _, _, _, _, castBarID = UnitCastingInfo(unitToken)
    if castBarID then
        pendingCastBarIDs[castGUID] = castBarID
    end
end

function JFCT.Events.OnSpellcastSucceeded(unitToken, castGUID, spellId)
    local castBarID = pendingCastBarIDs[castGUID]
    pendingCastBarIDs[castGUID] = nil  -- consume

    local spellName = C_Spell.GetSpellName(spellId)
    JFCT.CastTracker.OnCastSucceeded(unitToken, spellId, spellName or "", castBarID)
end

-- ---------------------------------------------------------------------------
-- Nameplate tracking
-- ---------------------------------------------------------------------------

local activePlates = {}  -- [unitToken] = nameplateFrame

function JFCT.Events.OnPlateAdded(unitToken)
    activePlates[unitToken] = C_NamePlate.GetNamePlateForUnit(unitToken)
end

function JFCT.Events.OnPlateRemoved(unitToken)
    activePlates[unitToken] = nil
end

-- Returns the nameplate frame for the current target, or nil
function JFCT.Events.GetTargetNameplate()
    for unitToken, plate in pairs(activePlates) do
        if UnitIsUnit(unitToken, "target") and plate and plate:IsShown() then
            return plate
        end
    end
    return nil
end
