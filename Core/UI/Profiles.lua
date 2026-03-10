-- Core/UI/Profiles.lua
-- Profile management tab: create, switch, delete, rename, import/export

local JFCT = JalleFCT
local C = JFCT.UI.Colors

-- ---------------------------------------------------------------------------
-- Simple text input box
-- ---------------------------------------------------------------------------

local function CreateEditBox(parent, w, h)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetSize(w, h)
    box:SetAutoFocus(false)
    box:SetFontObject("ChatFontNormal")
    box:SetTextInsets(6, 6, 0, 0)
    box:SetMaxLetters(200)
    JFCT.UI.SetSimpleBackdrop(box,
        C.bgDeep[1], C.bgDeep[2], C.bgDeep[3], 1,
        C.border[1], C.border[2], C.border[3], C.border[4])
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return box
end

-- ---------------------------------------------------------------------------
-- Multi-line scrollable text box (for import/export)
-- ---------------------------------------------------------------------------

local function CreateScrollEditBox(parent, w, h)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(w, h)
    JFCT.UI.SetSimpleBackdrop(container,
        C.bgDeep[1], C.bgDeep[2], C.bgDeep[3], 1,
        C.border[1], C.border[2], C.border[3], C.border[4])

    local scroll = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", -22, 4)

    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("ChatFontSmall")
    editBox:SetWidth(w - 30)
    editBox:SetTextInsets(4, 4, 4, 4)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    scroll:SetScrollChild(editBox)

    container.editBox = editBox
    return container
end

-- ---------------------------------------------------------------------------
-- Profiles tab builder
-- ---------------------------------------------------------------------------

function JFCT.UI.BuildProfilesTab(parent)
    local PAD = 22
    local y = -16

    -- ── Active Profile ──
    local activeLbl = parent:CreateFontString(nil, "OVERLAY")
    activeLbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "NONE")
    activeLbl:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
    activeLbl:SetText("Active Profile")
    activeLbl:SetPoint("TOPLEFT", PAD, y)
    y = y - 20

    -- Profile buttons container (rebuilt on changes)
    local profileBtnContainer = CreateFrame("Frame", nil, parent)
    profileBtnContainer:SetPoint("TOPLEFT", PAD, y)
    profileBtnContainer:SetSize(440, 30)

    local function RefreshProfileButtons()
        -- Clear existing children
        for _, child in ipairs({profileBtnContainer:GetChildren()}) do
            child:Hide()
            child:SetParent(nil)
        end

        local names = JFCT.Config.GetProfileNames()
        local active = JFCT.Config.GetActiveProfile()
        local bx = 0
        for _, name in ipairs(names) do
            local btn = JFCT.UI.CreateButton(profileBtnContainer, name, 90, 26)
            btn:SetPoint("TOPLEFT", bx, 0)
            btn:SetActive(name == active)
            btn:SetScript("OnClick", function()
                JFCT.Config.SwitchProfile(name)
            end)
            bx = bx + 94
        end
    end

    RefreshProfileButtons()
    y = y - 36

    -- ── New Profile ──
    local newLbl = parent:CreateFontString(nil, "OVERLAY")
    newLbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "NONE")
    newLbl:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
    newLbl:SetText("New Profile Name:")
    newLbl:SetPoint("TOPLEFT", PAD, y)
    y = y - 20

    local newInput = CreateEditBox(parent, 200, 24)
    newInput:SetPoint("TOPLEFT", PAD, y)

    local newBtn = JFCT.UI.CreateButton(parent, "Create (Copy Current)", 160, 24)
    newBtn:SetPoint("LEFT", newInput, "RIGHT", 8, 0)
    newBtn:SetScript("OnClick", function()
        local name = newInput:GetText():match("^%s*(.-)%s*$")
        if name and #name > 0 then
            local current = JFCT.Config.GetActiveProfile()
            if JFCT.Config.CreateProfile(name, current) then
                JFCT.Config.SwitchProfile(name)
            else
                print("|cffff4444JalleFCT:|r Profile '" .. name .. "' already exists.")
            end
            newInput:SetText("")
            newInput:ClearFocus()
        end
    end)
    newInput:SetScript("OnEnterPressed", function() newBtn:Click() end)
    y = y - 34

    -- ── Rename ──
    local renameLbl = parent:CreateFontString(nil, "OVERLAY")
    renameLbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "NONE")
    renameLbl:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
    renameLbl:SetText("Rename Active Profile To:")
    renameLbl:SetPoint("TOPLEFT", PAD, y)
    y = y - 20

    local renameInput = CreateEditBox(parent, 200, 24)
    renameInput:SetPoint("TOPLEFT", PAD, y)

    local renameBtn = JFCT.UI.CreateButton(parent, "Rename", 80, 24)
    renameBtn:SetPoint("LEFT", renameInput, "RIGHT", 8, 0)
    renameBtn:SetScript("OnClick", function()
        local newName = renameInput:GetText():match("^%s*(.-)%s*$")
        if newName and #newName > 0 then
            local oldName = JFCT.Config.GetActiveProfile()
            if JFCT.Config.RenameProfile(oldName, newName) then
                RefreshProfileButtons()
                print("|cff00ff00JalleFCT:|r Profile renamed to '" .. newName .. "'.")
            else
                print("|cffff4444JalleFCT:|r Could not rename — name may already exist.")
            end
            renameInput:SetText("")
            renameInput:ClearFocus()
        end
    end)
    renameInput:SetScript("OnEnterPressed", function() renameBtn:Click() end)

    -- Delete button
    local deleteBtn = JFCT.UI.CreateButton(parent, "Delete Active", 100, 24)
    deleteBtn:SetPoint("LEFT", renameBtn, "RIGHT", 8, 0)
    deleteBtn:SetScript("OnClick", function()
        local name = JFCT.Config.GetActiveProfile()
        if JFCT.Config.DeleteProfile(name) then
            print("|cff00ff00JalleFCT:|r Profile '" .. name .. "' deleted.")
        else
            print("|cffff4444JalleFCT:|r Cannot delete the last profile.")
        end
    end)
    y = y - 42

    -- ── Divider ──
    local div = parent:CreateTexture(nil, "ARTWORK")
    div:SetHeight(1)
    div:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
    div:SetPoint("TOPLEFT",  parent, "TOPLEFT",   PAD,  y)
    div:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD,  y)
    y = y - 16

    -- ── Export ──
    local exportLbl = parent:CreateFontString(nil, "OVERLAY")
    exportLbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "NONE")
    exportLbl:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
    exportLbl:SetText("Export Active Profile:")
    exportLbl:SetPoint("TOPLEFT", PAD, y)
    y = y - 18

    local exportBox = CreateScrollEditBox(parent, 440, 60)
    exportBox:SetPoint("TOPLEFT", PAD, y)
    y = y - 66

    local exportBtn = JFCT.UI.CreateButton(parent, "Generate Export String", 160, 24)
    exportBtn:SetPoint("TOPLEFT", PAD, y)
    exportBtn:SetScript("OnClick", function()
        local str = JFCT.Config.ExportProfile()
        if str then
            exportBox.editBox:SetText(str)
            exportBox.editBox:HighlightText()
            exportBox.editBox:SetFocus()
        end
    end)
    y = y - 36

    -- ── Import ──
    local importLbl = parent:CreateFontString(nil, "OVERLAY")
    importLbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "NONE")
    importLbl:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
    importLbl:SetText("Import Profile (paste string below):")
    importLbl:SetPoint("TOPLEFT", PAD, y)
    y = y - 18

    local importBox = CreateScrollEditBox(parent, 440, 60)
    importBox:SetPoint("TOPLEFT", PAD, y)
    y = y - 66

    local importNameInput = CreateEditBox(parent, 150, 24)
    importNameInput:SetPoint("TOPLEFT", PAD, y)
    importNameInput:SetText("Imported")

    local importBtn = JFCT.UI.CreateButton(parent, "Import", 80, 24)
    importBtn:SetPoint("LEFT", importNameInput, "RIGHT", 8, 0)
    importBtn:SetScript("OnClick", function()
        local str = importBox.editBox:GetText()
        local name = importNameInput:GetText():match("^%s*(.-)%s*$")
        if not name or #name == 0 then name = "Imported" end
        if str and #str > 0 then
            if JFCT.Config.ImportProfile(name, str) then
                JFCT.Config.SwitchProfile(name)
            end
            importBox.editBox:SetText("")
            importBox.editBox:ClearFocus()
        end
    end)
end
