-- Core/Animations.lua
-- Classic and Modern animation implementations

local JFCT = JalleFCT

-- Alternates left/right for the classic fan effect
local classicSide = 1

-- ---------------------------------------------------------------------------
-- Shared: build animation group, return it and attach OnFinished → pool release
-- ---------------------------------------------------------------------------

local function NewAnimGroup(frame, pool)
    if frame.animGroup then
        frame.animGroup:Stop()
        -- Don't nil it; creating a new group below will replace the reference
    end
    local ag = frame:CreateAnimationGroup()
    frame.animGroup = ag
    ag:SetScript("OnFinished", function()
        pool:Release(frame)
    end)
    return ag
end

-- ---------------------------------------------------------------------------
-- Classic animation
-- Reference: Classic Floating Combat Text (cfct) style
--   - Text rises straight up with a slight left/right fan per hit
--   - Crits get a quick scale-pop before rising
--   - Total duration ~1.6s
-- ---------------------------------------------------------------------------

function JFCT.Animations.PlayClassic(frame, isCrit, pool)
    local ag = NewAnimGroup(frame, pool)

    -- Alternate side, randomise magnitude slightly
    local xOff = classicSide * (18 + math.random(0, 12))
    classicSide = -classicSide

    -- Rise
    local rise = ag:CreateAnimation("Translation")
    rise:SetOffset(xOff, 90)
    rise:SetDuration(1.5)
    rise:SetOrder(1)
    rise:SetSmoothing("OUT")

    -- Hold full opacity for 1.0s, then fade out over 0.5s
    local hold = ag:CreateAnimation("Alpha")
    hold:SetFromAlpha(1)
    hold:SetToAlpha(1)
    hold:SetDuration(1.0)
    hold:SetOrder(1)

    local fade = ag:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetDuration(0.5)
    fade:SetStartDelay(1.0)
    fade:SetOrder(1)

    if isCrit then
        -- Scale pop: snap up then spring back before the rise begins
        local scaleUp = ag:CreateAnimation("Scale")
        scaleUp:SetScaleTo(1.55, 1.55)
        scaleUp:SetDuration(0.07)
        scaleUp:SetOrder(1)
        scaleUp:SetSmoothing("IN")

        local scaleDown = ag:CreateAnimation("Scale")
        scaleDown:SetScaleTo(1.0, 1.0)
        scaleDown:SetDuration(0.13)
        scaleDown:SetStartDelay(0.07)
        scaleDown:SetOrder(1)
        scaleDown:SetSmoothing("OUT")
    end

    ag:Play()
end

-- ---------------------------------------------------------------------------
-- Modern animation
--   - Soft arc drift, slight random horizontal wander
--   - Crits have a gentler scale pulse
--   - Total duration ~1.4s
-- ---------------------------------------------------------------------------

function JFCT.Animations.PlayModern(frame, isCrit, pool)
    local ag = NewAnimGroup(frame, pool)

    local xDrift = (math.random(0, 1) == 0 and 1 or -1) * math.random(8, 28)

    local move = ag:CreateAnimation("Translation")
    move:SetOffset(xDrift, 65)
    move:SetDuration(1.2)
    move:SetOrder(1)
    move:SetSmoothing("OUT")

    local fade = ag:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetDuration(0.55)
    fade:SetStartDelay(0.65)
    fade:SetOrder(1)

    if isCrit then
        local scaleUp = ag:CreateAnimation("Scale")
        scaleUp:SetScaleTo(1.35, 1.35)
        scaleUp:SetDuration(0.10)
        scaleUp:SetOrder(1)
        scaleUp:SetSmoothing("IN_OUT")

        local scaleDown = ag:CreateAnimation("Scale")
        scaleDown:SetScaleTo(1.0, 1.0)
        scaleDown:SetDuration(0.20)
        scaleDown:SetStartDelay(0.10)
        scaleDown:SetOrder(1)
        scaleDown:SetSmoothing("OUT")
    end

    ag:Play()
end
