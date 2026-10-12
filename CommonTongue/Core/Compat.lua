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
---@return string|nil
function Compat.PlayerName()
    local unitName = _G.UnitName
    if not unitName then
        return nil
    end
    return unitName("player")
end

---@return number
function Compat.GetTime()
    local getTime = _G.GetTime
    if getTime then
        return getTime()
    end
    return 0
end

--- Name without realm, for matching chat authors to addon-message senders.
---@param name string|nil
---@return string|nil
function Compat.ShortName(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    local ambiguate = _G.Ambiguate
    if ambiguate then
        return ambiguate(name, "short")
    end
    return name:match("^([^%-]+)") or name
end

--- PARTY, RAID, or INSTANCE_CHAT when grouped; nil when solo.
---@return string|nil
function Compat.GroupDistribution()
    local isInGroup = _G.IsInGroup
    if not isInGroup or not isInGroup() then
        return nil
    end
    local instanceCat = _G.LE_PARTY_CATEGORY_INSTANCE
    if instanceCat and isInGroup(instanceCat) then
        return "INSTANCE_CHAT"
    end
    local isInRaid = _G.IsInRaid
    if isInRaid and isInRaid() then
        return "RAID"
    end
    return "PARTY"
end

--- Sends visible chat. SAY/YELL/CHANNEL need a hardware event (click/keypress).
---@param text string
---@param chatType string
---@param target string|nil
---@return boolean
function Compat.SendChatMessage(text, chatType, target)
    if Compat.InChatLockdown() then
        return false
    end
    local chatInfo = _G.C_ChatInfo
    local api = chatInfo and chatInfo.SendChatMessage or _G.SendChatMessage
    if not api then
        return false
    end
    api(text, chatType, nil, target)
    return true
end

--- True when author is this character. Secret authors are treated as not-self.
---@param author string|nil
---@return boolean
function Compat.IsSelf(author)
    if not author or Compat.IsSecret(author) then
        return false
    end
    local player = Compat.PlayerName()
    if not player then
        return false
    end
    if author == player then
        return true
    end
    local short = author:match("^([^%-]+)")
    return short == player
end

function Compat.HookHyperlink(fn)
    local hook = _G.hooksecurefunc
    if hook then
        hook("SetItemRef", fn)
    end
end

---@param lines string[]
function Compat.ShowTooltip(lines)
    local tip = _G.GameTooltip
    if not tip or not lines then
        return
    end
    local owner = _G.UIParent or tip
    if tip.SetOwner then
        tip:SetOwner(owner, "ANCHOR_CURSOR")
    end
    if tip.ClearLines then
        tip:ClearLines()
    end
    for i = 1, #lines do
        tip:AddLine(lines[i])
    end
    tip:Show()
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
