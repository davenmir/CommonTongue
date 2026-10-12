local _, ns = ...
local Discovery = ns:NewModule("Discovery")

local HELLO_GAP = 5

local peers = {}
local lastAnnounce

---@param name string
---@param version string|nil
function Discovery.Note(name, version)
    if type(name) ~= "string" or name == "" then
        return
    end
    name = ns.Compat.ShortName(name) or name
    local peer = peers[name]
    if not peer then
        peer = {}
        peers[name] = peer
    end
    peer.version = version or peer.version
    peer.seen = ns.Compat.GetTime()
end

---@param name string
---@return table|nil
function Discovery.Get(name)
    name = ns.Compat.ShortName(name) or name
    return peers[name]
end

---@return table<string, table>
function Discovery.Peers()
    return peers
end

--- Broadcasts a hello on the current group channel. Throttled.
---@return boolean
function Discovery.Announce()
    if not ns.Transport.CanSend() then
        return false
    end
    local dist = ns.Compat.GroupDistribution()
    if not dist then
        return false
    end
    local now = ns.Compat.GetTime()
    if lastAnnounce and now - lastAnnounce < HELLO_GAP then
        return false
    end
    lastAnnounce = now
    local version = ns.Compat.GetAddOnMetadata(ns.name, "Version") or "?"
    return ns.Transport.Send(ns.Protocol.EncodeHello(version), dist)
end

function Discovery:OnRoster()
    Discovery.Announce()
end

function Discovery:OnEnable()
    ns.Events:Register("GROUP_ROSTER_UPDATE", self, "OnRoster")
    Discovery.Announce()
end
