local _, ns = ...
local Languages = ns:NewModule("Languages")

--- Supported languages, keyed by WoW client locale code, in display order.
Languages.CODES = {
    "enUS",
    "deDE",
    "esES",
    "esMX",
    "frFR",
    "itIT",
    "ptBR",
    "ruRU",
    "koKR",
    "zhCN",
    "zhTW",
}

-- Shown in each language's own script so speakers can find theirs; never localized.
Languages.NATIVE_NAMES = {
    enUS = "English",
    deDE = "Deutsch",
    esES = "Español (España)",
    esMX = "Español (Latinoamérica)",
    frFR = "Français",
    itIT = "Italiano",
    ptBR = "Português (Brasil)",
    ruRU = "Русский",
    koKR = "한국어",
    zhCN = "简体中文",
    zhTW = "繁體中文",
}

local ALIASES = {
    enGB = "enUS",
    ptPT = "ptBR",
}

---@param code string
---@return boolean
function Languages.IsSupported(code)
    return Languages.NATIVE_NAMES[code] ~= nil
end

--- Maps a client locale to a supported language code, defaulting to enUS.
---@param locale string|nil
---@return string
function Languages.Normalize(locale)
    locale = ALIASES[locale] or locale
    if locale and Languages.IsSupported(locale) then
        return locale
    end
    return "enUS"
end

--- Resolves the targetLanguage setting ("auto" or a code) to a language code.
---@param setting string
---@param clientLocale string
---@return string
function Languages.Resolve(setting, clientLocale)
    if setting ~= "auto" and Languages.IsSupported(setting) then
        return setting
    end
    return Languages.Normalize(clientLocale)
end
