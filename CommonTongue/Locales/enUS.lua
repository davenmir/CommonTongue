local _, ns = ...
local L = ns.L

-- Base locale. Keys are the English text; other locales override these keys.

L["Saved settings come from a newer version; some may be ignored."] = true
L["Enable CommonTongue"] = true
L["Target language"] = true
L["Chat in other languages will be shown in this language."] = true
L["Same as game client (%s)"] = true
L["Translate these chat types"] = true
L["Say"] = true
L["Yell"] = true
L["Emote"] = true
L["Party"] = true
L["Raid"] = true
L["Instance"] = true
L["Guild"] = true
L["Officer"] = true
L["Whisper"] = true
L["Battle.net whisper"] = true
L["Channels (Trade, General, custom)"] = true
L["Communities"] = true
L["Settings can't be opened in combat."] = true
L["Commands:"] = true
L["/ct - open settings"] = true
L["/ct version - show version"] = true
L["/ct debug - toggle debug mode"] = true
L["Version %s (%s)"] = true
L["Debug mode on. The addon namespace is available as CommonTongue."] = true
L["Debug mode off."] = true
L["Translate my own messages"] = true
L["For testing without a second player. Leave off during normal play."] = true
L["/ct self - toggle translating your own messages"] = true
L["Own-message translation on."] = true
L["Own-message translation off."] = true
L["[%s→%s]"] = true
L["[%s]"] = true
L["(unreviewed)"] = true
L["Original"] = true

for key, value in pairs(L) do
    if value == true then
        L[key] = key
    end
end
