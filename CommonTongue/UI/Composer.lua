local _, ns = ...
local Composer = ns:NewModule("Composer")

local L = ns.L
local LibStub = LibStub

local CATEGORIES = {
    { key = "courtesy", ids = { "HELLO", "BYE", "THANKS", "PLEASE", "GOOD_LUCK" } },
    {
        key = "lfg",
        ids = { "INVITE", "LFM_ROLES", "LFG_ACTIVITY", "I_AM_ROLE", "PLAY_ROLE", "SWITCH_ROLE" },
    },
    {
        key = "combat",
        ids = {
            "PULL",
            "PULL_IN",
            "READY",
            "INCOMING",
            "WIPE",
            "REZ",
            "INTERRUPT",
            "STACK",
            "SPREAD",
        },
    },
    { key = "trade", ids = { "WTS_ITEM_PRICE", "WTB_ITEM" } },
}

local CATEGORY_LABELS = {
    courtesy = L["Courtesy"],
    lfg = L["Looking for group"],
    combat = L["Combat"],
    trade = L["Trade"],
}

local SLOT_LABELS = {
    roles = L["Roles (tank, healer, dps)"],
    to = L["Switch to"],
    from = L["Switch from"],
    activity = L["Activity"],
    seconds = L["Seconds"],
    item = L["Item link"],
    price = L["Price"],
}

local CHANNELS = {
    SAY = L["Say"],
    PARTY = L["Party"],
    RAID = L["Raid"],
    INSTANCE_CHAT = L["Instance"],
    GUILD = L["Guild"],
    WHISPER = L["Whisper"],
}

local CHANNEL_ORDER = { "SAY", "PARTY", "RAID", "INSTANCE_CHAT", "GUILD", "WHISPER" }

---@return table<string, string> dropdown list
function Composer.PhraseList()
    local outgoing = ns.Languages.Normalize(ns.Compat.GetClientLocale())
    local list = {}
    for _, category in ipairs(CATEGORIES) do
        for _, id in ipairs(category.ids) do
            if ns.Data.GetPhrase(id) then
                local preview = ns.Phrase.Render(id, {}, outgoing)
                local label = preview and (id .. " — " .. preview) or id
                list[id] = CATEGORY_LABELS[category.key] .. " / " .. label:gsub("{%w+}", "…")
            end
        end
    end
    return list
end

---@param id string
---@return string[]
function Composer.Slots(id)
    local def = ns.Data.GetPhrase(id)
    if not def or not def.params then
        return {}
    end
    local slots = {}
    for slot in pairs(def.params) do
        slots[#slots + 1] = slot
    end
    table.sort(slots)
    return slots
end

---@param id string
---@param fields table<string, string>
---@return table|nil params
---@return string|nil error
function Composer.ParamsFromFields(id, fields)
    local def = ns.Data.GetPhrase(id)
    if not def then
        return nil, "unknown"
    end
    local params = {}
    for slot, typeName in pairs(def.params or {}) do
        local raw = fields and fields[slot] or ""
        raw = raw:match("^%s*(.-)%s*$") or ""
        if raw == "" then
            if typeName == "activity" then
                params[slot] = ""
            else
                return nil, slot
            end
        else
            local tokens = {}
            for token in raw:gmatch("%S+") do
                tokens[#tokens + 1] = token
            end
            if typeName == "roleList" then
                -- "tank, healer" or "tank healer"
                local collapsed = {}
                for token in raw:gmatch("[^,%s]+") do
                    collapsed[#collapsed + 1] = token
                end
                tokens = collapsed
            end
            local value = ns.Params.Parse(typeName, tokens, 1, #tokens)
            if not value then
                return nil, slot
            end
            params[slot] = value
        end
    end
    return params
end

--- Renders, correlates locally, optionally sends the protocol payload, then
--- sends visible chat. Must be called from a click/keypress (SAY needs it).
---@param id string
---@param params table
---@param chatType string
---@param target string|nil
---@return boolean
---@return string|nil
function Composer.Send(id, params, chatType, target)
    if ns.Compat.InChatLockdown() then
        return false, "lockdown"
    end
    local outgoing = ns.Languages.Normalize(ns.Compat.GetClientLocale())
    local visible = ns.Phrase.Render(id, params, outgoing)
    if not visible then
        return false, "unknown"
    end
    local payload = ns.Protocol.EncodePhrase(id, params, visible)
    local decoded = ns.Protocol.Decode(payload)
    local me = ns.Compat.ShortName(ns.Compat.PlayerName()) or ns.Compat.PlayerName()
    if decoded and me then
        ns.Correlate.Put(me, decoded)
    end
    local dist, dest = ns.Transport.DistForChat(chatType, target)
    if dist then
        ns.Transport.Send(payload, dist, dest)
    end
    if not ns.Compat.SendChatMessage(visible, chatType, dest or target) then
        return false, "send"
    end
    return true
end

local function slotLabel(slot)
    return SLOT_LABELS[slot] or slot
end

function Composer:rebuildParams()
    local group = self.paramGroup
    if not group then
        return
    end
    group:ReleaseChildren()
    self.paramBoxes = {}
    local AceGUI = self.AceGUI
    if not AceGUI or not self.selectedId then
        return
    end
    for _, slot in ipairs(Composer.Slots(self.selectedId)) do
        local box = AceGUI:Create("EditBox")
        box:SetLabel(slotLabel(slot))
        box:SetFullWidth(true)
        group:AddChild(box)
        self.paramBoxes[slot] = box
    end
end

function Composer:setStatus(text)
    if self.frame and self.frame.SetStatusText then
        self.frame:SetStatusText(text or "")
    end
end

function Composer:doSend()
    if not self.selectedId then
        self:setStatus(L["Pick a phrase first."])
        return
    end
    local fields = {}
    for slot, box in pairs(self.paramBoxes or {}) do
        fields[slot] = box:GetText()
    end
    local params, err = Composer.ParamsFromFields(self.selectedId, fields)
    if not params then
        self:setStatus(L["Fill in %s."]:format(slotLabel(err)))
        return
    end
    local target = self.whisperBox and self.whisperBox:GetText() or nil
    local ok, reason = Composer.Send(self.selectedId, params, self.channel or "SAY", target)
    if ok then
        self:setStatus(L["Sent."])
    elseif reason == "lockdown" then
        self:setStatus(L["Chat lockdown: CommonTongue can't send right now."])
    else
        self:setStatus(L["Couldn't send."])
    end
end

function Composer:Open()
    if ns.Compat.InCombat() then
        ns:Print(L["Settings can't be opened in combat."])
        return
    end
    local AceGUI = LibStub("AceGUI-3.0", true)
    if not AceGUI then
        ns:Print(L["Composer UI isn't available."])
        return
    end
    if self.frame then
        self.frame:Show()
        return
    end

    self.AceGUI = AceGUI
    self.channel = "SAY"
    self.paramBoxes = {}

    local frame = AceGUI:Create("Frame")
    frame:SetTitle(L["CommonTongue phrases"])
    frame:SetLayout("List")
    frame:SetWidth(420)
    frame:SetHeight(380)
    frame:EnableResize(false)
    frame:SetCallback("OnClose", function(widget)
        widget:Release()
        self.frame = nil
        self.paramGroup = nil
        self.whisperBox = nil
        self.AceGUI = nil
    end)

    local drop = AceGUI:Create("Dropdown")
    drop:SetLabel(L["Phrase"])
    drop:SetList(Composer.PhraseList())
    drop:SetFullWidth(true)
    drop:SetCallback("OnValueChanged", function(_, _, key)
        self.selectedId = key
        self:rebuildParams()
    end)
    frame:AddChild(drop)

    local paramGroup = AceGUI:Create("SimpleGroup")
    paramGroup:SetFullWidth(true)
    paramGroup:SetLayout("List")
    frame:AddChild(paramGroup)
    self.paramGroup = paramGroup

    local channel = AceGUI:Create("Dropdown")
    channel:SetLabel(L["Send to"])
    channel:SetList(CHANNELS)
    channel:SetValue("SAY")
    channel:SetFullWidth(true)
    channel:SetCallback("OnValueChanged", function(_, _, key)
        self.channel = key
    end)
    frame:AddChild(channel)

    local whisper = AceGUI:Create("EditBox")
    whisper:SetLabel(L["Whisper target"])
    whisper:SetFullWidth(true)
    frame:AddChild(whisper)
    self.whisperBox = whisper

    local send = AceGUI:Create("Button")
    send:SetText(L["Send"])
    send:SetFullWidth(true)
    send:SetCallback("OnClick", function()
        self:doSend()
    end)
    frame:AddChild(send)

    self.frame = frame
    if ns.Compat.InChatLockdown() then
        self:setStatus(L["Chat lockdown: CommonTongue can't send right now."])
    else
        self:setStatus(L["Pick a phrase, then Send."])
    end
end

Composer.CATEGORIES = CATEGORIES
Composer.CATEGORY_LABELS = CATEGORY_LABELS
Composer.CHANNEL_ORDER = CHANNEL_ORDER
