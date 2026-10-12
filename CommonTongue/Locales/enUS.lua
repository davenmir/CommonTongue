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
L["[CT→%s]"] = true
L["CommonTongue protocol"] = true
L["Exact translations between players who both run CommonTongue."] = true
L["Works in party, raid, guild, and whisper."] = true
L["/ct compose - open the phrase composer"] = true
L["/ct peers - list CommonTongue users seen this session"] = true
L["No CommonTongue users seen yet."] = true
L["%s (%s)"] = true
L["Courtesy"] = true
L["Looking for group"] = true
L["Combat"] = true
L["Trade"] = true
L["Roles (tank, healer, dps)"] = true
L["Switch to"] = true
L["Switch from"] = true
L["Activity"] = true
L["Seconds"] = true
L["Item link"] = true
L["Price"] = true
L["CommonTongue phrases"] = true
L["Phrase"] = true
L["Send to"] = true
L["Whisper target"] = true
L["Send"] = true
L["Pick a phrase first."] = true
L["Fill in %s."] = true
L["Sent."] = true
L["Chat lockdown: CommonTongue can't send right now."] = true
L["Couldn't send."] = true
L["Composer UI isn't available."] = true
L["Pick a phrase, then Send."] = true

for key, value in pairs(L) do
    if value == true then
        L[key] = key
    end
end
