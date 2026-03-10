-- Core/UI/SpellList.lua
-- Spells tab: scrollable list with per-spell toggle and size slider

local MCT = MidnightCombatText

local C = MCT.UI.Colors  -- set by Panel.lua which loads first

local ROW_H = 38

-- Builds (or rebuilds) the spell rows inside the scroll child
local function BuildRows(scrollChild, existingRows)
    -- Hide and detach any previous rows
    if existingRows then
        for _, row in ipairs(existingRows) do
            row:Hide()
            row:SetParent(nil)
        end
    end

    local rows  = {}
    local rowN  = 0
    local totalH = 0

    for spellId, spellName in pairs(MCT.db.knownSpells) do
        rowN = rowN + 1

        local row = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
        row:SetSize(scrollChild:GetWidth(), ROW_H)
        row:SetPoint("TOPLEFT", 0, -(rowN - 1) * ROW_H)
        row:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })

        -- Alternating row colour
        if rowN % 2 == 0 then
            row:SetBackdropColor(C.bgRow[1], C.bgRow[2], C.bgRow[3], 1)
        else
            row:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 1)
        end
        row:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.3)

        local sid = spellId  -- capture for closures

        -- Helper: create a small toggle box at a given left offset
        local function MakeToggleBox(leftOffset, getValue, setValue)
            local btn = CreateFrame("Button", nil, row, "BackdropTemplate")
            btn:SetSize(16, 16)
            btn:SetPoint("LEFT", leftOffset, 0)
            btn:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            btn:SetBackdropColor(C.bgDeep[1], C.bgDeep[2], C.bgDeep[3], 1)
            btn:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3])

            local mark = btn:CreateFontString(nil, "OVERLAY")
            mark:SetFont("Fonts\\FRIZQT__.TTF", 11, "NONE")
            mark:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
            mark:SetText("x")
            mark:SetAllPoints()
            mark:SetJustifyH("CENTER")
            mark:SetJustifyV("MIDDLE")

            local function Refresh(v)
                mark:SetAlpha(v and 1 or 0)
                if v then
                    btn:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3])
                else
                    btn:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3])
                end
            end

            Refresh(getValue())
            btn:SetScript("OnClick", function()
                local new = not getValue()
                setValue(new)
                Refresh(new)
            end)

            return btn
        end

        -- Show toggle
        MakeToggleBox(8,
            function() return MCT.Config.GetSpellFilter(sid) end,
            function(v) MCT.Config.SetSpellFilter(sid, v) end)

        -- Merge toggle (only meaningful when global merge is on)
        local mergeBtn = MakeToggleBox(32,
            function() return MCT.Config.GetSpellMerge(sid) end,
            function(v) MCT.Config.SetSpellMerge(sid, v) end)

        -- Dim merge toggle when global merge is off to signal it has no effect
        if not MCT.db.mergeHits then
            mergeBtn:SetAlpha(0.35)
        end

        -- Spell name (shifted right to make room for both toggles)
        local nameFs = row:CreateFontString(nil, "OVERLAY")
        nameFs:SetFont("Fonts\\FRIZQT__.TTF", 12, "NONE")
        nameFs:SetTextColor(C.text[1], C.text[2], C.text[3])
        nameFs:SetText(spellName)
        nameFs:SetPoint("LEFT", 56, 0)
        nameFs:SetWidth(148)
        nameFs:SetJustifyH("LEFT")
        nameFs:SetWordWrap(false)

        -- Size label
        local currentSize = MCT.Config.GetSpellSize(spellId)
        local sizeLabel = row:CreateFontString(nil, "OVERLAY")
        sizeLabel:SetFont("Fonts\\FRIZQT__.TTF", 10, "NONE")
        sizeLabel:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
        sizeLabel:SetText(string.format("%.1fx", currentSize))
        sizeLabel:SetPoint("RIGHT", -90, 0)

        -- Inline size slider
        local sizeSlider = CreateFrame("Slider", nil, row, "MinimalSliderTemplate")
        sizeSlider:SetSize(76, 12)
        sizeSlider:SetPoint("RIGHT", -8, 0)
        sizeSlider:SetMinMaxValues(0.5, 3.0)
        sizeSlider:SetValueStep(0.1)
        sizeSlider:SetObeyStepOnDrag(true)
        sizeSlider:SetValue(currentSize)

        local thumb = sizeSlider:GetThumbTexture()
        if thumb then
            thumb:SetColorTexture(C.text[1], C.text[2], C.text[3], 0.8)
            thumb:SetSize(6, 14)
        end

        sizeSlider:SetScript("OnValueChanged", function(self, v)
            MCT.Config.SetSpellSize(sid, v)
            sizeLabel:SetText(string.format("%.1fx", v))
        end)

        rows[rowN] = row
        totalH = rowN * ROW_H
    end

    scrollChild:SetHeight(math.max(1, totalH))
    return rows
end

function MCT.UI.BuildSpellsTab(parent)
    -- Header note
    local header = parent:CreateFontString(nil, "OVERLAY")
    header:SetFont("Fonts\\FRIZQT__.TTF", 11, "NONE")
    header:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
    header:SetText("New spells are added automatically when used in combat.")
    header:SetPoint("TOPLEFT", 22, -16)
    header:SetWidth(440)
    header:SetJustifyH("LEFT")

    -- Column headers
    local colShow = parent:CreateFontString(nil, "OVERLAY")
    colShow:SetFont("Fonts\\FRIZQT__.TTF", 10, "NONE")
    colShow:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
    colShow:SetText("Show")
    colShow:SetPoint("TOPLEFT", 22, -36)

    local colMerge = parent:CreateFontString(nil, "OVERLAY")
    colMerge:SetFont("Fonts\\FRIZQT__.TTF", 10, "NONE")
    colMerge:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
    colMerge:SetText("Merge")
    colMerge:SetPoint("TOPLEFT", 46, -36)

    local colName = parent:CreateFontString(nil, "OVERLAY")
    colName:SetFont("Fonts\\FRIZQT__.TTF", 10, "NONE")
    colName:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
    colName:SetText("Ability")
    colName:SetPoint("TOPLEFT", 76, -36)

    local colSize = parent:CreateFontString(nil, "OVERLAY")
    colSize:SetFont("Fonts\\FRIZQT__.TTF", 10, "NONE")
    colSize:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
    colSize:SetText("Size")
    colSize:SetPoint("TOPRIGHT", -10, -36)

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "MCT_SpellScroll", parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     parent, "TOPLEFT",      20,  -52)
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -38,    6)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    -- Initial build
    local rows = BuildRows(scrollChild, nil)

    -- Expose refresh so Config.RegisterSpell can trigger a rebuild
    function MCT.UI.RefreshSpellList()
        rows = BuildRows(scrollChild, rows)
    end
end
