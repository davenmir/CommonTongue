local _, ns = ...
local Slash = ns:NewModule("Slash")

local L = ns.L
local strtrim = strtrim

local function applyDebug(enabled)
    -- Debug-only global so developers can inspect state with /dump CommonTongue.
    CommonTongue = enabled and ns or nil
end

local commands = {}

commands[""] = function()
    ns.Settings:Open()
end

commands.version = function()
    local version = ns.Compat.GetAddOnMetadata(ns.name, "Version") or "?"
    ns:Print(L["Version %s (%s)"]:format(version, ns.Compat.flavor))
end

commands.debug = function()
    local global = ns.DB:Global()
    global.debug = not global.debug
    applyDebug(global.debug)
    if global.debug then
        ns:Print(L["Debug mode on. The addon namespace is available as CommonTongue."])
    else
        ns:Print(L["Debug mode off."])
    end
end

commands.self = function()
    local profile = ns.DB:Profile()
    profile.translateSelf = not profile.translateSelf
    if profile.translateSelf then
        ns:Print(L["Own-message translation on."])
    else
        ns:Print(L["Own-message translation off."])
    end
end

commands.compose = function()
    ns.Composer:Open()
end

commands.peers = function()
    local names = {}
    for name in pairs(ns.Discovery.Peers()) do
        names[#names + 1] = name
    end
    table.sort(names)
    if #names == 0 then
        ns:Print(L["No CommonTongue users seen yet."])
        return
    end
    for i = 1, #names do
        local peer = ns.Discovery.Get(names[i])
        local version = peer and peer.version or "?"
        ns:Print(L["%s (%s)"]:format(names[i], version))
    end
end

commands.help = function()
    ns:Print(L["Commands:"])
    ns:Print(L["/ct - open settings"])
    ns:Print(L["/ct version - show version"])
    ns:Print(L["/ct debug - toggle debug mode"])
    ns:Print(L["/ct self - toggle translating your own messages"])
    ns:Print(L["/ct compose - open the phrase composer"])
    ns:Print(L["/ct peers - list CommonTongue users seen this session"])
end

---@param input string|nil
function Slash.Handle(input)
    local command = strtrim(input or ""):lower()
    local handler = commands[command] or commands.help
    handler()
end

function Slash:OnInitialize()
    applyDebug(ns.DB:Global().debug)
    SLASH_COMMONTONGUE1 = "/ct"
    SLASH_COMMONTONGUE2 = "/commontongue"
    SlashCmdList.COMMONTONGUE = Slash.Handle
end
