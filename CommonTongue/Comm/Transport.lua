local _, ns = ...
local Transport = ns:NewModule("Transport")

local LibStub = LibStub

local CHAT_TO_DIST = {
    PARTY = "PARTY",
    RAID = "RAID",
    INSTANCE_CHAT = "INSTANCE_CHAT",
    INSTANCE = "INSTANCE_CHAT",
    GUILD = "GUILD",
    OFFICER = "OFFICER",
    WHISPER = "WHISPER",
}

--- Addon-message distribution for a visible chat type, or nil if none exists.
---@param chatType string
---@param target string|nil
---@return string|nil distribution
---@return string|nil target
function Transport.DistForChat(chatType, target)
    local dist = CHAT_TO_DIST[chatType]
    if not dist then
        return nil
    end
    if dist == "WHISPER" then
        if not target or target == "" then
            return nil
        end
        return dist, target
    end
    return dist
end

---@return boolean
function Transport.CanSend()
    if ns.DB and ns.DB.db and not ns.DB:Profile().protocol then
        return false
    end
    return not ns.Compat.InChatLockdown()
end

--- Sends an already-encoded payload. No-op during lockdown or if AceComm is missing.
---@param payload string
---@param distribution string
---@param target string|nil
---@return boolean
function Transport.Send(payload, distribution, target)
    if not Transport.CanSend() then
        return false
    end
    if not payload or not distribution or not Transport.SendCommMessage then
        return false
    end
    Transport:SendCommMessage(ns.Protocol.PREFIX, payload, distribution, target, "NORMAL")
    return true
end

function Transport:OnCommReceived(prefix, message, _, sender)
    if prefix ~= ns.Protocol.PREFIX then
        return
    end
    if ns.Compat.IsSecret(message) or ns.Compat.IsSecret(sender) then
        return
    end
    if ns.DB and ns.DB.db and not ns.DB:Profile().protocol then
        return
    end
    local decoded = ns.Protocol.Decode(message)
    if not decoded then
        return
    end
    local name = ns.Compat.ShortName(sender) or sender
    if decoded.kind == ns.Protocol.KIND_HELLO then
        ns.Discovery.Note(name, decoded.version)
    elseif decoded.kind == ns.Protocol.KIND_PHRASE then
        ns.Discovery.Note(name)
        ns.Correlate.Put(name, decoded)
    end
end

function Transport:OnInitialize()
    local AceComm = LibStub("AceComm-3.0", true)
    if not AceComm then
        return
    end
    AceComm:Embed(self)
    self:RegisterComm(ns.Protocol.PREFIX)
end
