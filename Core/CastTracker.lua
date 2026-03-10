-- Core/CastTracker.lua
-- Groups multi-hit events (e.g. dual-wield Execute) into a single display.
--
-- Strategy:
--   UNIT_SPELLCAST_SUCCEEDED sets up a pending group keyed by castBarID
--   (NeverSecret in 12.0).  When castBarID is unavailable (some abilities,
--   pets, open-world only), we fall back to a sourceGUID+spellId key.
--
--   CLEU SPELL_DAMAGE stores the last seen spell context.
--   COMBAT_TEXT_UPDATE consumes that context to correlate amount -> spell,
--   then routes into the appropriate pending group.

local MCT = MidnightCombatText

local GROUP_WINDOW = 0.06  -- seconds to wait for additional hits after the last one

-- Pending groups indexed by castBarID (preferred) or fallback key
-- { spellId, spellName, hits={...}, lastCrit, eventType, timer }
local pendingGroups = {}

-- Last CLEU damage context — consumed by the next OnCombatTextEvent call
-- { spellId, spellName, isPeriodic, groupKey, timestamp }
local lastCLEUCtx = nil

-- ---------------------------------------------------------------------------
-- Called by Events.lua: UNIT_SPELLCAST_SUCCEEDED
-- ---------------------------------------------------------------------------

function MCT.CastTracker.OnCastSucceeded(unitToken, spellId, spellName, castBarID)
    if not spellId then return end

    -- Prefer castBarID; fall back to a GUID+spellId string key
    local playerGUID = UnitGUID("player")
    local petGUID    = UnitGUID("pet")
    local srcGUID    = (unitToken == "pet" and petGUID) or playerGUID
    local groupKey   = castBarID and ("cb_" .. castBarID)
                       or (srcGUID .. "_" .. spellId)

    -- Cancel any previous group for this key
    local existing = pendingGroups[groupKey]
    if existing and existing.timer then
        existing.timer:Cancel()
    end

    pendingGroups[groupKey] = {
        spellId   = spellId,
        spellName = spellName,
        hits      = {},
        lastCrit  = false,
        eventType = "normal",
        timer     = nil,
    }
end

-- ---------------------------------------------------------------------------
-- Called by Events.lua: CLEU SPELL_DAMAGE / SWING_DAMAGE
-- ---------------------------------------------------------------------------

function MCT.CastTracker.OnCLEUDamage(sourceGUID, spellId, spellName, isPeriodic)
    -- Find the matching pending group to store its key
    local groupKey = nil

    -- Search by spellId match
    for key, group in pairs(pendingGroups) do
        if group.spellId == spellId then
            groupKey = key
            break
        end
    end

    -- Fallback key for abilities that didn't go through UNIT_SPELLCAST_SUCCEEDED
    if not groupKey then
        groupKey = sourceGUID .. "_" .. spellId
    end

    lastCLEUCtx = {
        spellId    = spellId,
        spellName  = spellName,
        isPeriodic = isPeriodic,
        groupKey   = groupKey,
        timestamp  = GetTime(),
    }
end

-- ---------------------------------------------------------------------------
-- Called by Events.lua: COMBAT_TEXT_UPDATE
-- ---------------------------------------------------------------------------

local CLEU_CORRELATE_WINDOW = 0.05  -- 50ms tolerance for CLEU/CTU ordering

function MCT.CastTracker.OnCombatTextEvent(amount, eventType, isCrit)
    if not MCT.db.enabled then return end

    -- Consume the CLEU context if it's fresh enough
    local spellId, spellName, groupKey
    local ctx = lastCLEUCtx
    if ctx and (GetTime() - ctx.timestamp) < CLEU_CORRELATE_WINDOW then
        spellId   = ctx.spellId
        spellName = ctx.spellName
        groupKey  = ctx.groupKey
        lastCLEUCtx = nil
    end

    -- Check per-spell filter
    if spellId and not MCT.Config.GetSpellFilter(spellId) then
        return
    end

    -- If merging is off globally, or disabled for this spell, or we have no group key, show immediately
    local spellMergeOn = not spellId or MCT.Config.GetSpellMerge(spellId)
    if not MCT.db.mergeHits or not spellMergeOn or not groupKey then
        MCT.Display.ShowHit({
            amount    = amount,
            spellId   = spellId,
            spellName = spellName,
            eventType = eventType,
            isCrit    = isCrit,
        })
        return
    end

    local group = pendingGroups[groupKey]

    -- No pending group means this is a standalone hit
    if not group then
        MCT.Display.ShowHit({
            amount    = amount,
            spellId   = spellId,
            spellName = spellName,
            eventType = eventType,
            isCrit    = isCrit,
        })
        return
    end

    -- Add hit to the group
    table.insert(group.hits, amount)
    if isCrit then group.lastCrit = true end
    if eventType ~= "normal" then group.eventType = eventType end
    group.spellId   = group.spellId or spellId
    group.spellName = group.spellName or spellName

    -- Restart flush timer: wait full GROUP_WINDOW after the LAST hit
    if group.timer then
        group.timer:Cancel()
    end

    local capturedKey = groupKey
    group.timer = C_Timer.NewTimer(GROUP_WINDOW, function()
        local g = pendingGroups[capturedKey]
        if not g then return end

        MCT.Display.ShowHit({
            amount    = g.hits,   -- table; Display handles summing or secret passthrough
            spellId   = g.spellId,
            spellName = g.spellName,
            eventType = g.eventType,
            isCrit    = g.lastCrit,
            merged    = #g.hits > 1,
        })
        pendingGroups[capturedKey] = nil
    end)
end
