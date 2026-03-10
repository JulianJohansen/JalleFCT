-- JalleFCT.lua
-- Namespace definition and addon lifecycle

-- Suppress the "has been blocked from an action" popup for this addon.
-- BackdropTemplate and other Blizzard mixins spread taint to secure frames;
-- the block is cosmetic and doesn't affect addon functionality.
do
    local origShow = StaticPopup_Show
    StaticPopup_Show = function(which, text_arg1, ...)
        if which == "ADDON_ACTION_FORBIDDEN" and
           type(text_arg1) == "string" and text_arg1:find("JalleFCT", 1, true) then
            return nil
        end
        return origShow(which, text_arg1, ...)
    end
end

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
        JFCT.Config.UpdateBlizzardFCT()
        JFCT.Events.Init()
        JFCT.Display.Init()
        JFCT.UI.Init()

    elseif event == "PLAYER_LOGOUT" then
        JFCT.TestMode.Stop()
    end
end)

SLASH_JFCT1 = "/jfct"
SlashCmdList["JFCT"] = function()
    JFCT.UI.Toggle()
end

SLASH_JFCTDEBUG1 = "/jfctdebug"
SlashCmdList["JFCTDEBUG"] = function()
    JFCT.Events.ToggleDebug()
end

SLASH_JFCTTEST1 = "/jfcttest"
SlashCmdList["JFCTTEST"] = function()
    print("|cff00ff00JFCT:|r Firing test hit...")
    JFCT.Display.ShowHit({
        amount    = 12345,
        eventType = "normal",
        isCrit    = false,
    })
end
