-- Core/Animations.lua
-- Classic and Modern animation implementations
-- Animations are created ONCE per frame and reused (matching MBT pattern).

local JFCT = JalleFCT

-- Alternates left/right for the classic fan effect
local classicSide = 1

-- ---------------------------------------------------------------------------
-- SetupAnimations: called once per pooled frame to create reusable anim objects
-- ---------------------------------------------------------------------------

function JFCT.Animations.Setup(frame, pool)
    -- Main group: translate + fade (used by both classic normal and modern)
    local ag = frame:CreateAnimationGroup()
    frame.animGroup = ag

    local translate = ag:CreateAnimation("Translation")
    translate:SetSmoothing("OUT")
    frame.translateAnim = translate

    local fade = ag:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    frame.fadeAnim = fade

    ag:SetScript("OnFinished", function()
        pool:Release(frame)
    end)

    -- Crit group: scale pop + hold + fade
    local cg = frame:CreateAnimationGroup()
    frame.critGroup = cg

    local scaleUp = cg:CreateAnimation("Scale")
    if scaleUp.SetScaleFrom then
        scaleUp:SetScaleFrom(1.5, 1.5)
        scaleUp:SetScaleTo(1.0, 1.0)
    elseif scaleUp.SetFromScale then
        scaleUp:SetFromScale(1.5, 1.5)
        scaleUp:SetToScale(1.0, 1.0)
    end
    scaleUp:SetDuration(0.12)
    scaleUp:SetSmoothing("OUT")
    scaleUp:SetOrder(1)
    frame.critScaleAnim = scaleUp

    local critHold = cg:CreateAnimation("Translation")
    critHold:SetOffset(0, 0)
    critHold:SetDuration(0.55)
    critHold:SetOrder(2)
    frame.critHoldAnim = critHold

    local critFade = cg:CreateAnimation("Alpha")
    critFade:SetFromAlpha(1)
    critFade:SetToAlpha(0)
    critFade:SetDuration(0.5)
    critFade:SetOrder(3)
    frame.critFadeAnim = critFade

    cg:SetScript("OnFinished", function()
        pool:Release(frame)
    end)
end

-- ---------------------------------------------------------------------------
-- Classic animation
-- Non-crits: float upward with fan spread, then fade
-- Crits: scale pop, hold, fade
-- ---------------------------------------------------------------------------

function JFCT.Animations.PlayClassic(frame, isCrit, pool)
    -- Ensure animations exist (first use from pool)
    if not frame.animGroup then
        JFCT.Animations.Setup(frame, pool)
    end

    if isCrit then
        -- Stop main group if running, use crit group
        frame.animGroup:Stop()
        frame.critGroup:Stop()
        frame.critGroup:Play()
    else
        -- Stop crit group if running, use main group
        frame.critGroup:Stop()
        frame.animGroup:Stop()

        local xOff = classicSide * (20 + math.random(0, 30))
        classicSide = -classicSide
        local yOff = 80 + math.random(0, 40)

        frame.translateAnim:SetOffset(xOff, yOff)
        frame.translateAnim:SetDuration(1.4)
        frame.translateAnim:SetOrder(1)
        frame.translateAnim:SetStartDelay(0)

        frame.fadeAnim:SetDuration(0.4)
        frame.fadeAnim:SetStartDelay(0.9)
        frame.fadeAnim:SetOrder(1)

        frame.animGroup:Play()
    end
end

-- ---------------------------------------------------------------------------
-- Modern animation
--   - Soft arc drift, slight random horizontal wander
--   - Crits get the scale pop from critGroup
-- ---------------------------------------------------------------------------

function JFCT.Animations.PlayModern(frame, isCrit, pool)
    -- Ensure animations exist (first use from pool)
    if not frame.animGroup then
        JFCT.Animations.Setup(frame, pool)
    end

    local xDrift = (math.random(0, 1) == 0 and 1 or -1) * math.random(15, 40)
    local yDrift = 60 + math.random(0, 40)

    -- Always use the main translate+fade group
    frame.critGroup:Stop()
    frame.animGroup:Stop()

    frame.translateAnim:SetOffset(xDrift, yDrift)
    frame.translateAnim:SetDuration(1.2)
    frame.translateAnim:SetOrder(1)
    frame.translateAnim:SetStartDelay(0)

    frame.fadeAnim:SetDuration(0.4)
    frame.fadeAnim:SetStartDelay(0.7)
    frame.fadeAnim:SetOrder(1)

    frame.animGroup:Play()

    -- Crits also get the scale bounce
    if isCrit then
        frame.critGroup:Play()
    end
end
