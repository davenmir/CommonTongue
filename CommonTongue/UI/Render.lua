local _, ns = ...
local Render = ns:NewModule("Render")

local L = ns.L

local LINK_TYPE = "garrmission"
local LINK_PREFIX = "CT"
local MAX_ORIGINALS = 64

local originals = {}
local originalOrder = {}
local nextId = 1

local SHORT = {
    enUS = "en",
    deDE = "de",
    esES = "es",
    esMX = "es",
    frFR = "fr",
    itIT = "it",
    ptBR = "pt",
    ruRU = "ru",
    koKR = "ko",
    zhCN = "zh",
    zhTW = "zh",
}

local function remember(original)
    local id = nextId
    nextId = nextId + 1
    originals[id] = original
    originalOrder[#originalOrder + 1] = id
    if #originalOrder > MAX_ORIGINALS then
        originals[table.remove(originalOrder, 1)] = nil
    end
    return id
end

---@param code string|nil
---@return string
function Render.ShortCode(code)
    return SHORT[code] or (code and code:sub(1, 2):lower()) or "?"
end

--- Phrase translation: language tag + hoverable rendered text.
---@return string
function Render.Phrase(translated, original, sourceLang, targetLang, reviewed)
    local id = remember(original)
    local tag = L["[%s→%s]"]:format(Render.ShortCode(sourceLang), Render.ShortCode(targetLang))
    local hover = "|H" .. LINK_TYPE .. ":" .. LINK_PREFIX .. ":" .. id .. "|h" .. translated .. "|h"
    local line = "|cff99ccff" .. tag .. "|r " .. hover
    if reviewed == false then
        line = line .. " |cff666666" .. L["(unreviewed)"] .. "|r"
    end
    return line
end

--- No phrase match: original text plus a language tag.
---@return string
function Render.LanguageTag(original, sourceLang)
    local tag = L["[%s]"]:format(Render.ShortCode(sourceLang))
    return original .. " |cff888888" .. tag .. "|r"
end

---@param id number
---@return string|nil
function Render.Original(id)
    return originals[id]
end

function Render.IsOurs(link)
    return type(link) == "string" and link:find(LINK_TYPE .. ":" .. LINK_PREFIX .. ":", 1, true)
end

function Render.IdFromLink(link)
    local id = link and link:match(LINK_PREFIX .. ":(%d+)")
    return id and tonumber(id)
end

function Render:OnEnable()
    ns.Compat.HookHyperlink(function(link)
        if not Render.IsOurs(link) then
            return
        end
        local original = Render.Original(Render.IdFromLink(link))
        if original then
            ns.Compat.ShowTooltip({ L["Original"], original })
        end
    end)
end
