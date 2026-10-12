local _, ns = ...
local Correlate = ns:NewModule("Correlate")

local wipe = wipe

local MAX_PENDING = 64
local WINDOW = 3

local pending = {}
local order = {}

local function keyFor(sender, corr)
    return sender .. "\0" .. corr
end

local function prune(now)
    local i = 1
    while i <= #order do
        local entry = order[i]
        if now - entry.at > WINDOW then
            pending[entry.key] = nil
            table.remove(order, i)
        else
            i = i + 1
        end
    end
end

--- Stores a decoded phrase payload until the matching chat line arrives.
---@param sender string
---@param payload table
function Correlate.Put(sender, payload)
    if type(sender) ~= "string" or sender == "" or type(payload) ~= "table" then
        return
    end
    if payload.kind ~= ns.Protocol.KIND_PHRASE or not payload.corr then
        return
    end
    sender = ns.Compat.ShortName(sender) or sender
    local now = ns.Compat.GetTime()
    prune(now)
    local key = keyFor(sender, payload.corr)
    if pending[key] == nil then
        order[#order + 1] = { key = key, at = now }
        if #order > MAX_PENDING then
            local old = table.remove(order, 1)
            pending[old.key] = nil
        end
    end
    pending[key] = payload
end

--- Consumes a matching payload for this sender and visible chat text.
---@param sender string
---@param text string
---@return table|nil
function Correlate.Take(sender, text)
    if type(sender) ~= "string" or type(text) ~= "string" then
        return nil
    end
    sender = ns.Compat.ShortName(sender) or sender
    local now = ns.Compat.GetTime()
    prune(now)
    local key = keyFor(sender, ns.Protocol.Corr(text))
    local payload = pending[key]
    if not payload then
        return nil
    end
    pending[key] = nil
    for i = 1, #order do
        if order[i].key == key then
            table.remove(order, i)
            break
        end
    end
    return payload
end

function Correlate.Clear()
    wipe(pending)
    wipe(order)
end
