local _, ns = ...
local DB = ns:NewModule("DB")

local LibStub = LibStub

--- Bump when the shape of CommonTongueDB changes, and add a migration below.
DB.SCHEMA_VERSION = 1

--- Chat type groups the user can toggle, in display order.
DB.CHAT_TYPES = {
    "SAY",
    "YELL",
    "EMOTE",
    "PARTY",
    "RAID",
    "INSTANCE",
    "GUILD",
    "OFFICER",
    "WHISPER",
    "BN_WHISPER",
    "CHANNEL",
    "COMMUNITIES",
}

local function defaultChatTypes()
    local types = {}
    for _, chatType in ipairs(DB.CHAT_TYPES) do
        types[chatType] = true
    end
    return types
end

DB.defaults = {
    global = {
        schemaVersion = 0,
        debug = false,
    },
    profile = {
        enabled = true,
        targetLanguage = "auto",
        chatTypes = defaultChatTypes(),
    },
}

--- migrations[n] upgrades raw saved data from schema n-1 to n. Schema 1 is the
--- initial layout and needs no migration.
DB.migrations = {}

--- Upgrades raw SavedVariables in place. Returns false if the data was written by
--- a newer CommonTongue, in which case it is left untouched.
---@param sv table
---@return boolean
function DB.Migrate(sv)
    sv.global = sv.global or {}
    local from = sv.global.schemaVersion or 0
    if from > DB.SCHEMA_VERSION then
        return false
    end
    for version = from + 1, DB.SCHEMA_VERSION do
        local migrate = DB.migrations[version]
        if migrate then
            migrate(sv)
        end
    end
    sv.global.schemaVersion = DB.SCHEMA_VERSION
    return true
end

function DB:OnInitialize()
    CommonTongueDB = CommonTongueDB or {}
    if not DB.Migrate(CommonTongueDB) then
        ns:Print(ns.L["Saved settings come from a newer version; some may be ignored."])
    end
    self.db = LibStub("AceDB-3.0"):New("CommonTongueDB", DB.defaults, true)
end

---@return table profile
function DB:Profile()
    return self.db.profile
end

---@return table global
function DB:Global()
    return self.db.global
end
