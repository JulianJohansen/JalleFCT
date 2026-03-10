-- Core/UI/TestMode.lua
-- Periodic fake hit display for live preview while editing settings

local JFCT = JalleFCT

local ticker   = nil
local INTERVAL = 1.4  -- seconds between fake hits

-- Weighted pool: more normals than crits, include dots and heals occasionally
local EVENT_POOL = {
    "normal", "normal", "normal",
    "crit",
    "dot",
    "hot",
    "miss",
}

local FALLBACK_SPELLS = {
    { id = 0, name = "Attack" },
    { id = 1, name = "Strike" },
    { id = 2, name = "Smite"  },
}

local function GetSpellPool()
    local class = JFCT.playerClass
    local pool  = class and JFCT.ClassData[class]
    if pool and #pool > 0 then return pool end
    return FALLBACK_SPELLS
end

local function FireFakeHit()
    if not JFCT.db.enabled then return end

    local spells    = GetSpellPool()
    local spell     = spells[math.random(1, #spells)]
    local eventType = EVENT_POOL[math.random(1, #EVENT_POOL)]
    local isCrit    = (eventType == "crit")

    -- Generate a plausible number in the range current content might produce.
    -- These are plain Lua numbers (test mode; no secrets involved).
    local base = math.random(4000, 55000)
    if isCrit then
        base = math.floor(base * (1.8 + math.random() * 0.6))
    end

    JFCT.Display.ShowTestHit(base, eventType, isCrit, spell.id, spell.name)
end

function JFCT.TestMode.Start()
    if ticker then return end          -- already running
    FireFakeHit()                      -- immediate first hit
    ticker = C_Timer.NewTicker(INTERVAL, FireFakeHit)
end

function JFCT.TestMode.Stop()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end
