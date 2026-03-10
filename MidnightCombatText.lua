-- MidnightCombatText.lua
-- Namespace definition and addon lifecycle

MidnightCombatText = {
    CastTracker = {},
    Display     = {},
    Events      = {},
    Config      = {},
    Animations  = {},
    ClassData   = {},
    TestMode    = {},
    UI          = {},

    playerClass = nil,  -- e.g. "WARRIOR", set on PLAYER_LOGIN
    db          = nil,  -- alias for MCT_Config, set on ADDON_LOADED
}

local MCT = MidnightCombatText

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_LOGOUT")

initFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName ~= "MidnightCombatText" then return end
        MCT.Config.Init()

    elseif event == "PLAYER_LOGIN" then
        local _, class = UnitClass("player")
        MCT.playerClass = class
        MCT.ClassData.PreloadClass(class)
        MCT.Events.Init()
        MCT.Display.Init()
        MCT.UI.Init()

        if MCT.db.enabled then
            CombatTextSetActiveUnit("player")
        end

    elseif event == "PLAYER_LOGOUT" then
        MCT.TestMode.Stop()
    end
end)

SLASH_MCT1 = "/mct"
SlashCmdList["MCT"] = function()
    MCT.UI.Toggle()
end
