local _, ns = ...
local Compat = ns:NewModule("Compat")

local _G = _G
local pcall, type = pcall, type

local PROJECT_FLAVORS = {
    WOW_PROJECT_MAINLINE = "Mainline",
    WOW_PROJECT_CLASSIC = "Vanilla",
    WOW_PROJECT_BURNING_CRUSADE_CLASSIC = "TBC",
    WOW_PROJECT_WRATH_CLASSIC = "Wrath",
    WOW_PROJECT_CATACLYSM_CLASSIC = "Cata",
    WOW_PROJECT_MISTS_CLASSIC = "Mists",
}

local function detectFlavor()
    local projectID = _G.WOW_PROJECT_ID
    if projectID == nil then
        return "Unknown"
    end
    for constant, flavor in pairs(PROJECT_FLAVORS) do
        if _G[constant] == projectID then
            return flavor
        end
    end
    return "Unknown"
end

--- One of "Mainline", "Vanilla", "TBC", "Wrath", "Cata", "Mists", "Unknown".
Compat.flavor = detectFlavor()
Compat.isRetail = Compat.flavor == "Mainline"

--- Event fired when addon restrictions (e.g. chat lockdown) change; nil if the flavor has none.
Compat.restrictionEvent = nil

--- Calls fn without letting its error escape; errors still reach the error handler (BugSack).
function Compat.SafeCall(fn, ...)
    if _G.securecallfunction then
        return _G.securecallfunction(fn, ...)
    end
    local ok, err = pcall(fn, ...)
    if not ok then
        _G.geterrorhandler()(err)
    end
end

---@return string|nil
function Compat.GetAddOnMetadata(addon, field)
    local api = _G.C_AddOns and _G.C_AddOns.GetAddOnMetadata or _G.GetAddOnMetadata
    return api and api(addon, field)
end

---@return string
function Compat.GetClientLocale()
    return _G.GetLocale()
end

function Compat.InCombat()
    return _G.InCombatLockdown() and true or false
end

function Compat.IsSecret(value)
    local issecretvalue = _G.issecretvalue
    return issecretvalue ~= nil and issecretvalue(value) or false
end

function Compat.InChatLockdown()
    local chatInfo = _G.C_ChatInfo
    if chatInfo and chatInfo.InChatMessagingLockdown then
        return chatInfo.InChatMessagingLockdown() and true or false
    end
    return false
end

local function filterApi(name)
    local util = _G.ChatFrameUtil
    if util and type(util[name]) == "function" then
        return util[name]
    end
    return _G["ChatFrame_" .. name]
end

function Compat.AddMessageEventFilter(event, fn)
    filterApi("AddMessageEventFilter")(event, fn)
end

function Compat.RemoveMessageEventFilter(event, fn)
    filterApi("RemoveMessageEventFilter")(event, fn)
end

--- Opens the addon's settings category. Returns false if it cannot open right now.
---@param categoryID any value returned by AceConfigDialog:AddToBlizOptions
---@return boolean
function Compat.OpenSettings(categoryID)
    if Compat.InCombat() then
        return false
    end
    local settings = _G.Settings
    if settings and settings.OpenToCategory then
        settings.OpenToCategory(categoryID)
        return true
    end
    return false
end
