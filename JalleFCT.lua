-- JalleFCT.lua
-- Namespace definition and addon lifecycle

JalleFCT = {
    CastTracker = {},
    Display     = {},
    Events      = {},
    Config      = {},
    Animations  = {},
    ClassData   = {},
    TestMode    = {},
    UI          = {},

    playerClass = nil,  -- e.g. "WARRIOR", set on PLAYER_LOGIN
    db          = nil,  -- alias for JalleFCT_Config, set on ADDON_LOADED
}

local JFCT = JalleFCT

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_LOGOUT")

initFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName ~= "JalleFCT" then return end
        JFCT.Config.Init()

    elseif event == "PLAYER_LOGIN" then
        local _, class = UnitClass("player")
        JFCT.playerClass = class
        JFCT.ClassData.PreloadClass(class)
        JFCT.Events.Init()
        JFCT.Display.Init()
        JFCT.UI.Init()

        if JFCT.db.enabled then
            CombatTextSetActiveUnit("player")
        end

    elseif event == "PLAYER_LOGOUT" then
        JFCT.TestMode.Stop()
    end
end)

SLASH_JFCT1 = "/jfct"
SlashCmdList["JFCT"] = function()
    JFCT.UI.Toggle()
end
