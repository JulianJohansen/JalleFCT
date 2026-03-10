-- Core/Display.lua
-- Frame pool management and hit display entry point

local JFCT = JalleFCT

-- Font defaults (overridden by db settings)
local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"
local DEFAULT_SIZE = 22

local pool
local activeCritFrames   = {}  -- keyed by plate (or "screen"), one crit per anchor
local activeNormalFrames = {}  -- keyed by plate (or "screen"), one normal per anchor

-- Reset a pooled frame to a clean state
local function ResetFrame(_, frame)
    frame:Hide()
    frame:ClearAllPoints()
    frame:SetParent(UIParent)
    if frame.animGroup then
        frame.animGroup:Stop()
    end
    if frame.critGroup then
        frame.critGroup:Stop()
    end
    if frame.text then
        frame.text:SetText("")
        frame.text:SetAlpha(1)
    end
    frame:SetScale(1)
    frame:SetAlpha(1)
    -- Clear per-plate tracking if this frame was active
    local key = frame._plateKey
    if key then
        if activeCritFrames[key] == frame then
            activeCritFrames[key] = nil
        end
        if activeNormalFrames[key] == frame then
            activeNormalFrames[key] = nil
        end
        frame._plateKey = nil
    end
end

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

local function GetAnchor(plate)
    if JFCT.db.anchorMode == "nameplate" and plate and plate:IsShown() then
        return plate, "TOP", JFCT.db.nameplateOffsetX or 0, JFCT.db.nameplateOffsetY or 0
    end
    -- Screen anchor (or nameplate fallback)
    return UIParent, "CENTER", JFCT.db.anchorX, JFCT.db.anchorY
end

-- ---------------------------------------------------------------------------
-- Sum helper (secret-safe)
-- ---------------------------------------------------------------------------

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
    local spellScale = spellId and JFCT.Config.GetSpellSize(spellId) or 1.0
    local baseSize   = JFCT.db.fontSize or DEFAULT_SIZE

    -- Per-type scale multiplier
    local typeScaleKey = eventType .. "Scale"
    local typeScale    = JFCT.db[typeScaleKey] or 1.0
    local fontSize     = baseSize * spellScale * typeScale

    -- Per-plate key: use the plate reference for nameplate-anchored hits,
    -- or the string "screen" for screen-centered hits
    local plate = hitData.plate
    local plateKey = plate or "screen"

    -- Crits replace the previous crit on the SAME plate only
    if isCrit and activeCritFrames[plateKey] then
        pool:Release(activeCritFrames[plateKey])
        activeCritFrames[plateKey] = nil
    elseif not isCrit and eventType == "normal" and activeNormalFrames[plateKey] then
        pool:Release(activeNormalFrames[plateKey])
        activeNormalFrames[plateKey] = nil
    end

    -- Acquire and configure frame
    local frame = pool:Acquire()
    frame._plateKey = plateKey
    frame:SetSize(220, 70)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(100)

    local anchor, point, ox, oy = GetAnchor(hitData.plate)

    -- Small random spawn jitter so simultaneous hits don't start at the exact same pixel
    local jitterX = math.random(-10, 10)
    local jitterY = math.random(-6, 6)

    -- For nameplate mode: re-parent to UIParent so the frame isn't clipped
    -- by the nameplate's bounds, and anchor BOTTOM of our frame to TOP of plate
    if anchor ~= UIParent then
        frame:SetParent(UIParent)
        frame:SetPoint("BOTTOM", anchor, point, ox + jitterX, oy + jitterY)
    else
        frame:SetPoint("CENTER", anchor, point, ox + jitterX, oy + jitterY)
    end

    -- Font string (create once per pooled frame)
    if not frame.text then
        frame.text = frame:CreateFontString(nil, "OVERLAY")
        frame.text:SetPoint("CENTER")
        frame.text:SetJustifyH("CENTER")
        frame.text:SetJustifyV("MIDDLE")
    end

    local fontPath  = JFCT.db.font or DEFAULT_FONT
    local fontFlags = JFCT.db.fontFlags or "OUTLINE"
    if fontFlags == "NONE" then fontFlags = "" end

    -- Crits: render font at 2x and set frame scale to 0.5 so the resting
    -- visual size equals fontSize.  The Scale animation zooms from 1.5 DOWN
    -- to 1.0 — always downscaling the 2x bitmap, so text stays crisp.
    if isCrit then
        frame.text:SetFont(fontPath, fontSize * 2, fontFlags)
        frame:SetScale(0.5)
    else
        frame.text:SetFont(fontPath, fontSize, fontFlags)
        frame:SetScale(1)
    end

    if JFCT.db.fontShadow then
        frame.text:SetShadowOffset(JFCT.db.fontShadowX or 1, JFCT.db.fontShadowY or -1)
        frame.text:SetShadowColor(0, 0, 0, 0.8)
    else
        frame.text:SetShadowOffset(0, 0)
    end

    frame.text:SetTextColor(GetColor(eventType))
    frame.text:SetText(displayAmount)
    frame.text:SetAlpha(1)

    frame:Show()

    -- Track active crit / normal frame per plate
    if isCrit then
        activeCritFrames[plateKey] = frame
    elseif eventType == "normal" then
        activeNormalFrames[plateKey] = frame
    end

    -- Check personal best on crits
    local isGlobalBest = false
    if isCrit and spellId and JFCT.sv then
        local _, gb = JFCT.Config.CheckPersonalBest(spellId, displayAmount)
        isGlobalBest = gb
    end

    -- Dispatch animation
    if isGlobalBest then
        JFCT.Animations.PlayGlobalBest(frame)
    else
        JFCT.Animations.ResetCritScale(frame)
    end

    if JFCT.db.animStyle == "classic" then
        JFCT.Animations.PlayClassic(frame, isCrit, pool)
    else
        JFCT.Animations.PlayModern(frame, isCrit, pool)
    end
end

-- Clean up tracking when a nameplate is removed
function JFCT.Display.OnPlateRemoved(plate)
    if plate then
        activeCritFrames[plate] = nil
        activeNormalFrames[plate] = nil
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
