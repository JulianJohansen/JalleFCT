-- .luacheckrc for MidnightCombatText
-- WoW Lua is Lua 5.1 compatible (strict subset)

std = "lua51"
max_line_length = false
codes = true

-- Our addon globals (mutable)
globals = {
    "MidnightCombatText",
    "MCT_Config",
    "SLASH_MCT1",
    "SlashCmdList",   -- WoW global table; we set keys into it
}

-- Read-only WoW globals (API functions, tables, constants)
read_globals = {
    -- Core frame/widget creation
    "CreateFrame",
    "CreateFramePool",
    "UIParent",
    "CopyTable",

    -- Backdrop (requires "BackdropTemplate" mixin in modern WoW)
    "BackdropTemplateMixin",

    -- Font / texture constants
    "STANDARD_TEXT_FONT",

    -- Events & scripting
    "GetTime",

    -- Combat log
    "CombatLogGetCurrentEventInfo",

    -- Combat text
    "GetCurrentCombatTextEventInfo",
    "CombatTextSetActiveUnit",

    -- Unit info
    "UnitGUID",
    "UnitClass",
    "UnitCastingInfo",
    "UnitIsUnit",

    -- Spell info (12.0 namespace)
    "C_Spell",

    -- Nameplate
    "C_NamePlate",

    -- Combat log restriction check (12.0)
    "C_CombatLog",

    -- Timers
    "C_Timer",

    -- Color picker
    "ColorPickerFrame",

    -- SavedVariables / slash commands are in globals (mutable) above

    -- String/math extras WoW exposes
    "string",
    "math",
    "table",
    "pairs",
    "ipairs",
    "tostring",
    "tonumber",
    "type",
    "pcall",
    "error",
    "assert",
    "select",
    "unpack",
    "rawget",
    "rawset",
    "next",
    "setmetatable",
    "getmetatable",
    "collectgarbage",
    "print",
    "format",  -- WoW exposes string.format as a global alias

    -- WoW event constants (strings; referenced as values not globals,
    -- but listed here to suppress undefined-global warnings if used)

    -- Misc WoW globals
    "issecretvalue",
    "wipe",
    "tinsert",
    "tremove",
    "tContains",
    "strsplit",
    "strjoin",
    "strtrim",
    "date",
    "time",
    "debugstack",
    "geterrorhandler",
    "seterrorhandler",
    "securecall",
    "hooksecurefunc",
    "issecure",
    "forceinsecure",

    -- Addon communication
    "SendAddonMessage",
    "RegisterAddonMessagePrefix",
}

-- Ignore line-length and some style warnings we don't care about
ignore = {
    "212",  -- unused argument (common in WoW event handlers)
    "411",  -- redefining local (sometimes needed in closures)
}

