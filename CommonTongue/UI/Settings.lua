local _, ns = ...
local SettingsPanel = ns:NewModule("Settings")

local L = ns.L
local LibStub = LibStub

local APP_NAME = "CommonTongue"

local CHAT_TYPE_LABELS = {
    SAY = L["Say"],
    YELL = L["Yell"],
    EMOTE = L["Emote"],
    PARTY = L["Party"],
    RAID = L["Raid"],
    INSTANCE = L["Instance"],
    GUILD = L["Guild"],
    OFFICER = L["Officer"],
    WHISPER = L["Whisper"],
    BN_WHISPER = L["Battle.net whisper"],
    CHANNEL = L["Channels (Trade, General, custom)"],
    COMMUNITIES = L["Communities"],
}

local function profile()
    return ns.DB:Profile()
end

local function languageValues()
    local Languages = ns.Languages
    local client = Languages.Normalize(ns.Compat.GetClientLocale())
    local values = {
        auto = L["Same as game client (%s)"]:format(Languages.NATIVE_NAMES[client]),
    }
    for _, code in ipairs(Languages.CODES) do
        values[code] = Languages.NATIVE_NAMES[code]
    end
    return values
end

local function languageSorting()
    local order = { "auto" }
    for _, code in ipairs(ns.Languages.CODES) do
        order[#order + 1] = code
    end
    return order
end

local function chatTypeToggles()
    local args = {}
    for i, chatType in ipairs(ns.DB.CHAT_TYPES) do
        args[chatType] = {
            type = "toggle",
            order = i,
            name = CHAT_TYPE_LABELS[chatType],
            get = function()
                return profile().chatTypes[chatType]
            end,
            set = function(_, value)
                profile().chatTypes[chatType] = value
            end,
        }
    end
    return args
end

--- AceConfig options table for the settings panel.
---@return table
function SettingsPanel.BuildOptions()
    return {
        type = "group",
        name = APP_NAME,
        args = {
            enabled = {
                type = "toggle",
                order = 1,
                width = "full",
                name = L["Enable CommonTongue"],
                get = function()
                    return profile().enabled
                end,
                set = function(_, value)
                    profile().enabled = value
                end,
            },
            targetLanguage = {
                type = "select",
                order = 2,
                width = "double",
                name = L["Target language"],
                desc = L["Chat in other languages will be shown in this language."],
                values = languageValues,
                sorting = languageSorting,
                get = function()
                    return profile().targetLanguage
                end,
                set = function(_, value)
                    profile().targetLanguage = value
                end,
            },
            translateSelf = {
                type = "toggle",
                order = 2.5,
                width = "full",
                name = L["Translate my own messages"],
                desc = L["For testing without a second player. Leave off during normal play."],
                get = function()
                    return profile().translateSelf
                end,
                set = function(_, value)
                    profile().translateSelf = value
                end,
            },
            chatTypes = {
                type = "group",
                inline = true,
                order = 3,
                name = L["Translate these chat types"],
                args = chatTypeToggles(),
            },
        },
    }
end

function SettingsPanel:OnInitialize()
    LibStub("AceConfig-3.0"):RegisterOptionsTable(APP_NAME, SettingsPanel.BuildOptions)
    local _, categoryID = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(APP_NAME, APP_NAME)
    self.categoryID = categoryID
end

function SettingsPanel:Open()
    if not ns.Compat.OpenSettings(self.categoryID) then
        ns:Print(L["Settings can't be opened in combat."])
    end
end
