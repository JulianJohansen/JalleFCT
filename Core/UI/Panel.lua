-- Core/UI/Panel.lua
-- Main options window: framework, shared helpers, General tab, Colors tab

local JFCT = JalleFCT

-- ---------------------------------------------------------------------------
-- Color palette
-- ---------------------------------------------------------------------------

JFCT.UI.Colors = {
    bg      = { 0.14, 0.14, 0.14, 0.97 },
    bgDeep  = { 0.10, 0.10, 0.10, 1.00 },
    bgRow   = { 0.12, 0.12, 0.12, 1.00 },
    border  = { 0.24, 0.24, 0.24, 1.00 },
    text    = { 0.92, 0.90, 0.85, 1.00 },
    textDim = { 0.62, 0.60, 0.57, 1.00 },
    accent  = { 0.80, 0.70, 0.30, 1.00 },
}

local C = JFCT.UI.Colors  -- shorthand

-- ---------------------------------------------------------------------------
-- Shared widget helpers
-- ---------------------------------------------------------------------------

local function SetBackdropDark(frame)
    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], C.bg[4])
    frame:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3])
end

-- Flat button with hover highlight
function JFCT.UI.CreateButton(parent, label, w, h)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(w or 100, h or 24)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(C.bgDeep[1], C.bgDeep[2], C.bgDeep[3], 1)
    btn:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3])

    local fs = btn:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Fonts\\FRIZQT__.TTF", 11, "NONE")
    fs:SetTextColor(C.text[1], C.text[2], C.text[3])
    fs:SetText(label)
    fs:SetAllPoints()
    fs:SetJustifyH("CENTER")
    fs:SetJustifyV("MIDDLE")
    btn.label = fs

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.20, 0.20, 0.20, 1)
        self:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3])
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(C.bgDeep[1], C.bgDeep[2], C.bgDeep[3], 1)
        self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3])
    end)

    -- Highlight active state
    function btn:SetActive(active)
        if active then
            self:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3])
            self.label:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
        else
            self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3])
            self.label:SetTextColor(C.text[1], C.text[2], C.text[3])
        end
    end

    return btn
end

-- Checkbox toggle
function JFCT.UI.CreateToggle(parent, label, initialValue, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(260, 20)

    local box = CreateFrame("Button", nil, container, "BackdropTemplate")
    box:SetSize(16, 16)
    box:SetPoint("LEFT", 0, 0)
    box:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    box:SetBackdropColor(C.bgDeep[1], C.bgDeep[2], C.bgDeep[3], 1)
    box:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3])

    local check = box:CreateFontString(nil, "OVERLAY")
    check:SetFont("Fonts\\FRIZQT__.TTF", 12, "NONE")
    check:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
    check:SetText("|")   -- simple tick using pipe; replaced below
    check:SetAllPoints()
    check:SetJustifyH("CENTER")
    check:SetJustifyV("MIDDLE")

    local labelFs = container:CreateFontString(nil, "OVERLAY")
    labelFs:SetFont("Fonts\\FRIZQT__.TTF", 12, "NONE")
    labelFs:SetTextColor(C.text[1], C.text[2], C.text[3])
    labelFs:SetText(label)
    labelFs:SetPoint("LEFT", box, "RIGHT", 7, 0)

    local value = initialValue

    local function Refresh()
        if value then
            check:SetText("x")
            check:SetAlpha(1)
            box:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3])
        else
            check:SetAlpha(0)
            box:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3])
        end
    end

    box:SetScript("OnClick", function()
        value = not value
        Refresh()
        if onChange then onChange(value) end
    end)

    Refresh()

    function container:SetValue(v) value = v; Refresh() end
    function container:GetValue() return value end

    return container
end

-- Labelled slider
function JFCT.UI.CreateSlider(parent, label, minVal, maxVal, step, init, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(220, 42)

    local labelFs = container:CreateFontString(nil, "OVERLAY")
    labelFs:SetFont("Fonts\\FRIZQT__.TTF", 11, "NONE")
    labelFs:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
    labelFs:SetPoint("TOPLEFT", 0, 0)
    labelFs:SetText(label)

    local valueFs = container:CreateFontString(nil, "OVERLAY")
    valueFs:SetFont("Fonts\\FRIZQT__.TTF", 11, "NONE")
    valueFs:SetTextColor(C.text[1], C.text[2], C.text[3])
    valueFs:SetPoint("TOPRIGHT", 0, 0)

    local slider = CreateFrame("Slider", nil, container, "MinimalSliderTemplate")
    slider:SetSize(220, 14)
    slider:SetPoint("BOTTOMLEFT", 0, 2)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(init)

    -- Style thumb
    local thumb = slider:GetThumbTexture()
    if thumb then
        thumb:SetColorTexture(C.text[1], C.text[2], C.text[3], 0.85)
        thumb:SetSize(7, 16)
    end

    local function UpdateValue(v)
        local fmt = (step < 1) and "%.1f" or "%d"
        valueFs:SetText(string.format(fmt, v))
    end

    UpdateValue(init)

    slider:SetScript("OnValueChanged", function(self, v)
        UpdateValue(v)
        if onChange then onChange(v) end
    end)

    function container:SetValue(v) slider:SetValue(v); UpdateValue(v) end

    return container
end

-- ---------------------------------------------------------------------------
-- Main panel
-- ---------------------------------------------------------------------------

local mainPanel

local function BuildMainPanel()
    mainPanel = CreateFrame("Frame", "JFCT_Panel", UIParent, "BackdropTemplate")
    mainPanel:SetSize(500, 540)
    mainPanel:SetPoint("CENTER")
    mainPanel:SetFrameStrata("DIALOG")
    mainPanel:SetMovable(true)
    mainPanel:EnableMouse(true)
    mainPanel:RegisterForDrag("LeftButton")
    mainPanel:SetScript("OnDragStart", mainPanel.StartMoving)
    mainPanel:SetScript("OnDragStop",  mainPanel.StopMovingOrSizing)
    mainPanel:Hide()

    SetBackdropDark(mainPanel)

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, mainPanel, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT",  mainPanel, "TOPLEFT",   1, -1)
    titleBar:SetPoint("TOPRIGHT", mainPanel, "TOPRIGHT", -1, -1)
    titleBar:SetHeight(34)
    titleBar:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    titleBar:SetBackdropColor(C.bgDeep[1], C.bgDeep[2], C.bgDeep[3], 1)
    titleBar:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3])

    local title = titleBar:CreateFontString(nil, "OVERLAY")
    title:SetFont("Fonts\\FRIZQT__.TTF", 13, "NONE")
    title:SetTextColor(C.text[1], C.text[2], C.text[3])
    title:SetText("JalleFCT")
    title:SetPoint("LEFT", 14, 0)

    local closeBtn = JFCT.UI.CreateButton(mainPanel, "x", 26, 26)
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() mainPanel:Hide() end)

    -- Tab bar
    local tabBarBg = CreateFrame("Frame", nil, mainPanel, "BackdropTemplate")
    tabBarBg:SetPoint("TOPLEFT",  mainPanel, "TOPLEFT",   1, -35)
    tabBarBg:SetPoint("TOPRIGHT", mainPanel, "TOPRIGHT",  -1, -35)
    tabBarBg:SetHeight(30)
    tabBarBg:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    tabBarBg:SetBackdropColor(C.bgDeep[1], C.bgDeep[2], C.bgDeep[3], 1)
    tabBarBg:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3])

    -- Content area (below tab bar, above bottom bar)
    local tabContents = {}
    local TAB_NAMES = { "General", "Spells", "Colors" }

    for i = 1, #TAB_NAMES do
        local content = CreateFrame("Frame", nil, mainPanel)
        content:SetPoint("TOPLEFT",     mainPanel, "TOPLEFT",   0, -66)
        content:SetPoint("BOTTOMRIGHT", mainPanel, "BOTTOMRIGHT", 0, 44)
        content:Hide()
        tabContents[i] = content
    end

    -- Tab buttons
    local tabs = {}
    local TAB_W = 100

    local function SelectTab(idx)
        for i, tab in ipairs(tabs) do
            local active = (i == idx)
            tab:SetActive(active)
            tabContents[i]:SetShown(active)
        end
    end

    for i, name in ipairs(TAB_NAMES) do
        local tab = JFCT.UI.CreateButton(tabBarBg, name, TAB_W, 30)
        tab:SetPoint("TOPLEFT", (i - 1) * TAB_W, 0)
        -- Underline accent
        local uline = tab:CreateTexture(nil, "OVERLAY")
        uline:SetHeight(2)
        uline:SetPoint("BOTTOMLEFT",  tab, "BOTTOMLEFT",   3, 1)
        uline:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -3, 1)
        uline:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
        tab.underline = uline

        -- Override SetActive to also toggle underline
        local origSetActive = tab.SetActive
        function tab:SetActive(v)
            origSetActive(self, v)
            if v then
                uline:Show()
            else
                uline:Hide()
            end
        end

        tab:SetScript("OnClick", function() SelectTab(i) end)
        tabs[i] = tab
    end

    -- Bottom bar (test button)
    local bottomBar = CreateFrame("Frame", nil, mainPanel, "BackdropTemplate")
    bottomBar:SetPoint("BOTTOMLEFT",  mainPanel, "BOTTOMLEFT",  1,  1)
    bottomBar:SetPoint("BOTTOMRIGHT", mainPanel, "BOTTOMRIGHT", -1, 1)
    bottomBar:SetHeight(42)
    bottomBar:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    bottomBar:SetBackdropColor(C.bgDeep[1], C.bgDeep[2], C.bgDeep[3], 1)
    bottomBar:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3])

    local testBtn = JFCT.UI.CreateButton(bottomBar, "Test Mode: OFF", 150, 28)
    testBtn:SetPoint("RIGHT", -10, 0)

    local testActive = false
    testBtn:SetScript("OnClick", function()
        testActive = not testActive
        testBtn.label:SetText(testActive and "Test Mode: ON" or "Test Mode: OFF")
        testBtn:SetActive(testActive)
        if testActive then
            JFCT.TestMode.Start()
        else
            JFCT.TestMode.Stop()
        end
    end)

    -- Stop test mode indicator when TestMode.Stop is called externally
    local origStop = JFCT.TestMode.Stop
    JFCT.TestMode.Stop = function()
        origStop()
        testActive = false
        testBtn.label:SetText("Test Mode: OFF")
        testBtn:SetActive(false)
    end

    -- Build tab contents
    JFCT.UI.BuildGeneralTab(tabContents[1])
    JFCT.UI.BuildSpellsTab(tabContents[2])
    JFCT.UI.BuildColorsTab(tabContents[3])

    SelectTab(1)
    mainPanel.SelectTab = SelectTab

    return mainPanel
end

function JFCT.UI.Init()
    BuildMainPanel()
end

function JFCT.UI.Toggle()
    if mainPanel then
        mainPanel:SetShown(not mainPanel:IsShown())
    end
end

-- ---------------------------------------------------------------------------
-- General tab
-- ---------------------------------------------------------------------------

function JFCT.UI.BuildGeneralTab(parent)
    local PAD = 22
    local y   = -16

    -- Enable
    local enableToggle = JFCT.UI.CreateToggle(parent, "Enable JalleFCT",
        JFCT.db.enabled, function(v) JFCT.Config.Set("enabled", v) end)
    enableToggle:SetPoint("TOPLEFT", PAD, y)
    y = y - 30

    -- Merge hits
    local mergeToggle = JFCT.UI.CreateToggle(parent, "Merge multi-hit spells (e.g. Execute)",
        JFCT.db.mergeHits, function(v) JFCT.Config.Set("mergeHits", v) end)
    mergeToggle:SetPoint("TOPLEFT", PAD, y)
    y = y - 36

    -- Divider
    local divLine = parent:CreateTexture(nil, "ARTWORK")
    divLine:SetHeight(1)
    divLine:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
    divLine:SetPoint("TOPLEFT",  parent, "TOPLEFT",   PAD,  y)
    divLine:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD,  y)
    y = y - 18

    -- Animation style label
    local animLbl = parent:CreateFontString(nil, "OVERLAY")
    animLbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "NONE")
    animLbl:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
    animLbl:SetText("Animation Style")
    animLbl:SetPoint("TOPLEFT", PAD, y)
    y = y - 22

    local classicBtn = JFCT.UI.CreateButton(parent, "Classic", 94, 26)
    classicBtn:SetPoint("TOPLEFT", PAD, y)

    local modernBtn = JFCT.UI.CreateButton(parent, "Modern", 94, 26)
    modernBtn:SetPoint("TOPLEFT", PAD + 102, y)

    local function RefreshAnimBtns()
        classicBtn:SetActive(JFCT.db.animStyle == "classic")
        modernBtn:SetActive(JFCT.db.animStyle == "modern")
    end
    classicBtn:SetScript("OnClick", function() JFCT.Config.Set("animStyle", "classic"); RefreshAnimBtns() end)
    modernBtn:SetScript("OnClick",  function() JFCT.Config.Set("animStyle", "modern");  RefreshAnimBtns() end)
    RefreshAnimBtns()
    y = y - 42

    -- Divider
    local divLine2 = parent:CreateTexture(nil, "ARTWORK")
    divLine2:SetHeight(1)
    divLine2:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
    divLine2:SetPoint("TOPLEFT",  parent, "TOPLEFT",   PAD,  y)
    divLine2:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD,  y)
    y = y - 18

    -- Anchor mode label
    local anchorLbl = parent:CreateFontString(nil, "OVERLAY")
    anchorLbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "NONE")
    anchorLbl:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
    anchorLbl:SetText("Anchor To")
    anchorLbl:SetPoint("TOPLEFT", PAD, y)
    y = y - 22

    local screenBtn = JFCT.UI.CreateButton(parent, "Screen",    94, 26)
    screenBtn:SetPoint("TOPLEFT", PAD, y)

    local plateBtn = JFCT.UI.CreateButton(parent, "Nameplate", 94, 26)
    plateBtn:SetPoint("TOPLEFT", PAD + 102, y)
    y = y - 34

    -- Screen position sliders
    local screenSliders = CreateFrame("Frame", nil, parent)
    screenSliders:SetPoint("TOPLEFT", PAD, y)
    screenSliders:SetSize(300, 90)

    local sX = JFCT.UI.CreateSlider(screenSliders, "X Offset", -800, 800, 1,
        JFCT.db.anchorX, function(v) JFCT.Config.Set("anchorX", v) end)
    sX:SetPoint("TOPLEFT", 0, 0)

    local sY = JFCT.UI.CreateSlider(screenSliders, "Y Offset", -600, 600, 1,
        JFCT.db.anchorY, function(v) JFCT.Config.Set("anchorY", v) end)
    sY:SetPoint("TOPLEFT", 0, -46)

    -- Nameplate offset sliders
    local plateSliders = CreateFrame("Frame", nil, parent)
    plateSliders:SetPoint("TOPLEFT", PAD, y)
    plateSliders:SetSize(300, 90)

    local pX = JFCT.UI.CreateSlider(plateSliders, "X Offset", -200, 200, 1,
        JFCT.db.nameplateOffsetX, function(v) JFCT.Config.Set("nameplateOffsetX", v) end)
    pX:SetPoint("TOPLEFT", 0, 0)

    local pY = JFCT.UI.CreateSlider(plateSliders, "Y Offset", -50, 200, 1,
        JFCT.db.nameplateOffsetY, function(v) JFCT.Config.Set("nameplateOffsetY", v) end)
    pY:SetPoint("TOPLEFT", 0, -46)

    local function RefreshAnchorBtns()
        local isScreen = JFCT.db.anchorMode == "screen"
        screenBtn:SetActive(isScreen)
        plateBtn:SetActive(not isScreen)
        screenSliders:SetShown(isScreen)
        plateSliders:SetShown(not isScreen)
    end

    screenBtn:SetScript("OnClick", function() JFCT.Config.Set("anchorMode", "screen");    RefreshAnchorBtns() end)
    plateBtn:SetScript("OnClick",  function() JFCT.Config.Set("anchorMode", "nameplate"); RefreshAnchorBtns() end)
    RefreshAnchorBtns()
end

-- ---------------------------------------------------------------------------
-- Colors tab
-- ---------------------------------------------------------------------------

function JFCT.UI.BuildColorsTab(parent)
    local PAD = 22
    local y   = -16

    local header = parent:CreateFontString(nil, "OVERLAY")
    header:SetFont("Fonts\\FRIZQT__.TTF", 11, "NONE")
    header:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
    header:SetText("Click a swatch to change the color.")
    header:SetPoint("TOPLEFT", PAD, y)
    y = y - 28

    local colorDefs = {
        { key = "normal", label = "Normal Damage" },
        { key = "crit",   label = "Critical Hits"  },
        { key = "dot",    label = "DoT Damage"     },
        { key = "hot",    label = "HoT Healing"    },
        { key = "heal",   label = "Direct Healing" },
        { key = "miss",   label = "Misses / Dodges / Parries" },
    }

    for _, def in ipairs(colorDefs) do
        local key = def.key

        -- Swatch
        local swatch = CreateFrame("Button", nil, parent, "BackdropTemplate")
        swatch:SetSize(22, 22)
        swatch:SetPoint("TOPLEFT", PAD, y)
        swatch:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        local col = JFCT.db.colors[key]
        swatch:SetBackdropColor(col.r, col.g, col.b, 1)
        swatch:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3])

        local label = parent:CreateFontString(nil, "OVERLAY")
        label:SetFont("Fonts\\FRIZQT__.TTF", 12, "NONE")
        label:SetTextColor(C.text[1], C.text[2], C.text[3])
        label:SetText(def.label)
        label:SetPoint("LEFT", swatch, "RIGHT", 10, 0)

        swatch:SetScript("OnClick", function()
            local current = JFCT.db.colors[key]
            ColorPickerFrame:SetupColorPickerAndShow({
                r           = current.r,
                g           = current.g,
                b           = current.b,
                hasOpacity  = false,
                swatchFunc  = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    JFCT.db.colors[key] = { r = r, g = g, b = b }
                    swatch:SetBackdropColor(r, g, b, 1)
                end,
                cancelFunc  = function(prev)
                    JFCT.db.colors[key] = { r = prev.r, g = prev.g, b = prev.b }
                    swatch:SetBackdropColor(prev.r, prev.g, prev.b, 1)
                end,
            })
        end)

        y = y - 34
    end
end
