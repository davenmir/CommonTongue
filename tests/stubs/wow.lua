-- Minimal fake WoW client API. install() resets every global the addon or the
-- embedded libraries touch and returns a state table that specs inspect and drive.

local M = {}

local PROJECT_IDS = {
    WOW_PROJECT_MAINLINE = 1,
    WOW_PROJECT_CLASSIC = 2,
    WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 5,
    WOW_PROJECT_WRATH_CLASSIC = 11,
    WOW_PROJECT_CATACLYSM_CLASSIC = 14,
    WOW_PROJECT_MISTS_CLASSIC = 19,
}

local function strtrim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function newFrame(state)
    local frame = { events = {}, scripts = {} }
    function frame:RegisterEvent(event)
        self.events[event] = true
    end
    function frame:UnregisterEvent(event)
        self.events[event] = nil
    end
    function frame:UnregisterAllEvents()
        self.events = {}
    end
    function frame:IsEventRegistered(event)
        return self.events[event] == true
    end
    function frame:SetScript(name, fn)
        self.scripts[name] = fn
    end
    function frame:GetScript(name)
        return self.scripts[name]
    end
    state.frames[#state.frames + 1] = frame
    return frame
end

--- A stand-in for a secret value: an opaque table, so any string operation on it
--- errors just as it would on a real secret.
function M.secret(label)
    return setmetatable({}, {
        __tostring = function()
            error("attempt to tostring a secret value (" .. tostring(label) .. ")")
        end,
    })
end

---@param opts table|nil { flavor = "WOW_PROJECT_MAINLINE", locale = "enUS", savedVariables = {} }
function M.install(opts)
    opts = opts or {}
    local state = {
        frames = {},
        errors = {},
        printed = {},
        filters = {},
        openedCategory = nil,
        locale = opts.locale or "enUS",
        loggedIn = false,
        inCombat = false,
        lockdown = false,
        secrets = setmetatable({}, { __mode = "k" }),
        metadata = { Version = "1.2.3" },
    }

    function state.fire(event, ...)
        for _, frame in ipairs(state.frames) do
            local handler = frame.scripts.OnEvent
            if frame.events[event] and handler then
                handler(frame, event, ...)
            end
        end
    end

    for name, id in pairs(PROJECT_IDS) do
        _G[name] = id
    end
    _G.WOW_PROJECT_ID = PROJECT_IDS[opts.flavor or "WOW_PROJECT_MAINLINE"]

    _G.LibStub = nil
    _G.CommonTongue = nil
    _G.CommonTongueDB = opts.savedVariables
    _G.SLASH_COMMONTONGUE1 = nil
    _G.SLASH_COMMONTONGUE2 = nil
    _G.SlashCmdList = {}

    _G.CreateFrame = function()
        return newFrame(state)
    end
    _G.IsLoggedIn = function()
        return state.loggedIn
    end
    _G.InCombatLockdown = function()
        return state.inCombat
    end
    _G.GetLocale = function()
        return state.locale
    end
    _G.GetRealmName = function()
        return "TestRealm"
    end
    _G.GetCurrentRegion = function()
        return 1
    end
    _G.GetCurrentRegionName = function()
        return "US"
    end
    _G.UnitName = function()
        return "Tester"
    end
    _G.UIParent = { name = "UIParent" }
    _G.GameTooltip = {
        lines = {},
        shown = false,
        SetOwner = function() end,
        ClearLines = function(self)
            self.lines = {}
        end,
        AddLine = function(self, line)
            self.lines[#self.lines + 1] = line
        end,
        Show = function(self)
            self.shown = true
        end,
    }
    _G.hooksecurefunc = function(name, fn)
        state.hooks = state.hooks or {}
        state.hooks[name] = fn
    end
    _G.UnitClass = function()
        return "Mage", "MAGE"
    end
    _G.UnitRace = function()
        return "Human", "Human"
    end
    _G.UnitFactionGroup = function()
        return "Alliance", "Alliance"
    end

    _G.geterrorhandler = function()
        return function(err)
            state.errors[#state.errors + 1] = err
        end
    end
    _G.securecallfunction = function(fn, ...)
        local ok, err = pcall(fn, ...)
        if not ok then
            state.errors[#state.errors + 1] = err
        end
    end

    _G.issecretvalue = function(value)
        return state.secrets[value] == true
    end
    _G.C_AddOns = {
        GetAddOnMetadata = function(_, field)
            return state.metadata[field]
        end,
    }
    _G.C_ChatInfo = {
        InChatMessagingLockdown = function()
            return state.lockdown
        end,
    }
    _G.ChatFrameUtil = {
        AddMessageEventFilter = function(event, fn)
            state.filters[event] = fn
        end,
        RemoveMessageEventFilter = function(event)
            state.filters[event] = nil
        end,
    }
    _G.ChatFrame_AddMessageEventFilter = nil
    _G.ChatFrame_RemoveMessageEventFilter = nil
    _G.GetAddOnMetadata = nil
    _G.Settings = {
        OpenToCategory = function(id)
            state.openedCategory = id
        end,
    }

    _G.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do
            parts[i] = tostring((select(i, ...)))
        end
        state.printed[#state.printed + 1] = table.concat(parts, " ")
    end

    _G.strtrim = strtrim
    _G.wipe = function(t)
        for k in pairs(t) do
            t[k] = nil
        end
        return t
    end
    _G.tinsert = table.insert
    _G.tremove = table.remove

    return state
end

--- Registers fake AceConfig/AceConfigDialog with LibStub; they record calls on state.
function M.installAceConfigFakes(state)
    local LibStub = _G.LibStub
    local config = LibStub:NewLibrary("AceConfig-3.0", 1)
    function config:RegisterOptionsTable(app, options)
        state.optionsApp = app
        state.options = options
    end
    local dialog = LibStub:NewLibrary("AceConfigDialog-3.0", 1)
    function dialog:AddToBlizOptions(app, name)
        state.blizApp, state.blizName = app, name
        return {}, "category-id-" .. app
    end
end

return M
