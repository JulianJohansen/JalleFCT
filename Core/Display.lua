-- Core/Display.lua
-- Frame pool management and hit display entry point

local JFCT = JalleFCT

local BASE_FONT = "Fonts\\FRIZQT__.TTF"
local BASE_SIZE = 22

-- Reset a pooled frame to a clean state
local function ResetFrame(_, frame)
    frame:Hide()
    frame:ClearAllPoints()
    if frame.animGroup then
        frame.animGroup:Stop()
    end
    if frame.text then
        frame.text:SetText("")
        frame.text:SetAlpha(1)
    end
    frame:SetScale(1)
    frame:SetAlpha(1)
end

local pool

function JFCT.Display.Init()
    pool = CreateFramePool("Frame", UIParent, nil, ResetFrame)
end

-- ---------------------------------------------------------------------------
-- Color resolution
-- ---------------------------------------------------------------------------

local function GetColor(eventType)
    local c = JFCT.db.colors
    if     eventType == "crit" then return c.crit.r,   c.crit.g,   c.crit.b
    elseif eventType == "dot"  then return c.dot.r,    c.dot.g,    c.dot.b
    elseif eventType == "hot"  then return c.hot.r,    c.hot.g,    c.hot.b
    elseif eventType == "miss" then return c.miss.r,   c.miss.g,   c.miss.b
    elseif eventType == "heal" then return c.heal.r,   c.heal.g,   c.heal.b
    else                            return c.normal.r, c.normal.g, c.normal.b
    end
end

-- ---------------------------------------------------------------------------
-- Anchor resolution
-- ---------------------------------------------------------------------------

local function GetAnchor()
    if JFCT.db.anchorMode == "nameplate" then
        local plate = JFCT.Events.GetTargetNameplate()
        if plate then
            return plate, "BOTTOM", JFCT.db.nameplateOffsetX, JFCT.db.nameplateOffsetY
        end
    end
    -- Screen anchor (or nameplate fallback)
    return UIParent, "CENTER", JFCT.db.anchorX, JFCT.db.anchorY
end

-- ---------------------------------------------------------------------------
-- Sum helper (secret-safe)
-- ---------------------------------------------------------------------------

-- In restricted encounters amounts may be secret values.
-- We can pass secrets directly to FontString:SetText(), but we cannot do
-- arithmetic on them.  If summing fails, fall back to the last hit value.
local function SumAmounts(amounts)
    local ok, result = pcall(function()
        local total = 0
        for _, v in ipairs(amounts) do
            total = total + v
        end
        return total
    end)
    return ok and result or amounts[#amounts]
end

-- ---------------------------------------------------------------------------
-- ShowHit  (main entry point)
-- hitData = {
--   amount    = number | table-of-numbers  (may be secret)
--   spellId   = number | nil
--   spellName = string | nil
--   eventType = "normal"|"crit"|"dot"|"hot"|"heal"|"miss"
--   isCrit    = bool
--   merged    = bool
-- }
-- ---------------------------------------------------------------------------

function JFCT.Display.ShowHit(hitData)
    if not JFCT.db.enabled then return end
    if not pool then return end

    local spellId   = hitData.spellId
    local eventType = hitData.eventType or "normal"
    local isCrit    = hitData.isCrit or false

    -- Resolve display amount
    local displayAmount
    if type(hitData.amount) == "table" then
        displayAmount = SumAmounts(hitData.amount)
    else
        displayAmount = hitData.amount
    end

    -- Per-spell scale
    local scale    = spellId and JFCT.Config.GetSpellSize(spellId) or 1.0
    local fontSize = BASE_SIZE * scale
    if isCrit then fontSize = fontSize * 1.25 end

    -- Acquire and configure frame
    local frame = pool:Acquire()
    frame:SetSize(220, 70)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(100)

    local anchor, point, ox, oy = GetAnchor()
    frame:SetPoint("CENTER", anchor, point, ox, oy)

    -- Font string (create once per pooled frame)
    if not frame.text then
        frame.text = frame:CreateFontString(nil, "OVERLAY")
        frame.text:SetPoint("CENTER")
        frame.text:SetJustifyH("CENTER")
        frame.text:SetJustifyV("MIDDLE")
    end

    frame.text:SetFont(BASE_FONT, fontSize, "OUTLINE")
    frame.text:SetTextColor(GetColor(eventType))
    frame.text:SetText(displayAmount)  -- SetText accepts secret values directly
    frame.text:SetAlpha(1)

    frame:Show()

    -- Dispatch animation
    if JFCT.db.animStyle == "classic" then
        JFCT.Animations.PlayClassic(frame, isCrit, pool)
    else
        JFCT.Animations.PlayModern(frame, isCrit, pool)
    end
end

-- Exposed for TestMode
function JFCT.Display.ShowTestHit(amount, eventType, isCrit, spellId, spellName)
    JFCT.Display.ShowHit({
        amount    = amount,
        spellId   = spellId,
        spellName = spellName,
        eventType = eventType,
        isCrit    = isCrit,
    })
end
