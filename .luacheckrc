std = "lua51"
max_line_length = 100
codes = true
-- Colon-style methods that ignore self are normal for module APIs.
self = false

exclude_files = {
    "CommonTongue/Libs/**",
    "spikes/**",
    "tools/bin/**",
    ".luarocks/**",
}

-- The only globals the addon may write: SavedVariables and slash command registration.
globals = {
    "CommonTongue", -- only while /ct debug is on
    "CommonTongueDB",
    "SLASH_COMMONTONGUE1",
    "SLASH_COMMONTONGUE2",
    SlashCmdList = { fields = { COMMONTONGUE = { read_only = false } } },
}

read_globals = {
    "C_AddOns",
    "C_ChatInfo",
    "C_SettingsUtil",
    "C_Timer",
    "ChatFrame_AddMessageEventFilter",
    "ChatFrame_RemoveMessageEventFilter",
    "ChatFrameUtil",
    "CreateFrame",
    "DEFAULT_CHAT_FRAME",
    "GetAddOnMetadata",
    "GetBuildInfo",
    "GetLocale",
    "InCombatLockdown",
    "IsLoggedIn",
    "LibStub",
    "Settings",
    "WOW_PROJECT_BURNING_CRUSADE_CLASSIC",
    "WOW_PROJECT_CATACLYSM_CLASSIC",
    "WOW_PROJECT_CLASSIC",
    "WOW_PROJECT_ID",
    "WOW_PROJECT_MAINLINE",
    "WOW_PROJECT_MISTS_CLASSIC",
    "WOW_PROJECT_WRATH_CLASSIC",
    "debugprofilestop",
    "geterrorhandler",
    "issecretvalue",
    "securecallfunction",
    "strjoin",
    "strlenutf8",
    "strsplit",
    "strtrim",
    "tinsert",
    "tremove",
    "wipe",
}

files["tests/**"] = {
    std = "+busted",
    -- Stubs install fake WoW globals; specs read them.
    ignore = { "111", "112", "113", "121", "122", "143" },
}

files["tools/**"] = {
    std = "lua51",
    ignore = { "113" },
}
