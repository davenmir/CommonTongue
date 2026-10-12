local ADDON_NAME, ns = ...
local Events = ns:NewModule("Events")

local error, type = error, type

-- event -> array of { owner, fn }. Arrays are replaced, never mutated, so a handler
-- can (un)register during dispatch without disturbing the loop in progress.
local handlers = {}
local frame = CreateFrame("Frame")

frame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then
        return
    end
    for i = 1, #list do
        local entry = list[i]
        ns.Compat.SafeCall(entry.fn, entry.owner, event, ...)
    end
end)

--- Subscribes owner to event. fn is a function or the name of a method on owner,
--- called as fn(owner, event, ...).
---@param event string
---@param owner table
---@param fn function|string
function Events:Register(event, owner, fn)
    if type(fn) == "string" then
        fn = owner[fn]
    end
    if type(fn) ~= "function" then
        error("CommonTongue: Events:Register needs a function or method name", 2)
    end

    local old = handlers[event]
    local list = {}
    if old then
        for i = 1, #old do
            if old[i].owner == owner then
                error(("CommonTongue: %s already registered for this owner"):format(event), 2)
            end
            list[i] = old[i]
        end
    end
    list[#list + 1] = { owner = owner, fn = fn }
    handlers[event] = list

    if not old then
        frame:RegisterEvent(event)
    end
end

---@param event string
---@param owner table
function Events:Unregister(event, owner)
    local old = handlers[event]
    if not old then
        return
    end
    local list = {}
    for i = 1, #old do
        if old[i].owner ~= owner then
            list[#list + 1] = old[i]
        end
    end
    if #list == 0 then
        handlers[event] = nil
        frame:UnregisterEvent(event)
    else
        handlers[event] = list
    end
end

---@param event string
---@return boolean
function Events:IsRegistered(event, owner)
    local list = handlers[event]
    if not list then
        return false
    end
    for i = 1, #list do
        if owner == nil or list[i].owner == owner then
            return true
        end
    end
    return false
end

Events:Register("ADDON_LOADED", Events, function(_, _, loadedName)
    if loadedName ~= ADDON_NAME then
        return
    end
    Events:Unregister("ADDON_LOADED", Events)
    ns:Initialize()
    if IsLoggedIn() then
        ns:Enable()
    end
end)

Events:Register("PLAYER_LOGIN", Events, function()
    Events:Unregister("PLAYER_LOGIN", Events)
    ns:Enable()
end)
