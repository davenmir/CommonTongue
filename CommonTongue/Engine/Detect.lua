local _, ns = ...
local Detect = ns:NewModule("Detect")

-- Shared WoW slang is ignored when scoring Latin languages.
local IGNORE = {
    lfm = true,
    lfg = true,
    wts = true,
    wtb = true,
    pst = true,
    inv = true,
    tank = true,
    tanks = true,
    heal = true,
    healer = true,
    healers = true,
    dps = true,
    plus = true,
    key = true,
    keys = true,
    raid = true,
    mythic = true,
    heroic = true,
    normal = true,
    gold = true,
    g = true,
}

-- Distinctive function / courtesy words. Weighted more than trigrams.
local WORDS = {
    enUS = {
        the = 2,
        ["and"] = 2,
        ["for"] = 2,
        you = 2,
        with = 1,
        this = 1,
        that = 1,
        have = 1,
        need = 1,
        looking = 2,
        please = 1,
        thanks = 1,
        thank = 1,
        anyone = 1,
        group = 1,
    },
    deDE = {
        und = 3,
        der = 2,
        die = 2,
        das = 2,
        ich = 2,
        nicht = 2,
        fur = 3, -- folded für; chat often drops the umlaut
        mit = 2,
        ein = 1,
        eine = 1,
        suche = 3,
        danke = 3,
        bitte = 2,
        gruppe = 2,
        heiler = 2,
        uber = 1,
    },
    esES = {
        y = 2,
        para = 3,
        el = 1,
        la = 1,
        que = 2,
        un = 1,
        una = 1,
        con = 1,
        por = 1,
        busco = 3,
        grupo = 2,
        sanador = 2,
        tanque = 2,
        gracias = 3,
        hola = 2,
    },
    esMX = {
        y = 2,
        para = 3,
        el = 1,
        la = 1,
        que = 2,
        un = 1,
        una = 1,
        con = 1,
        por = 1,
        busco = 3,
        grupo = 2,
        sanador = 2,
        tanque = 2,
        gracias = 3,
        hola = 2,
    },
    frFR = {
        et = 2,
        les = 2,
        pour = 3,
        une = 1,
        des = 1,
        que = 1,
        je = 1,
        cherche = 3,
        merci = 3,
        groupe = 2,
        soi = 1,
    },
    itIT = {
        che = 2,
        per = 3,
        una = 1,
        con = 1,
        non = 1,
        cerco = 3,
        grazie = 3,
        gruppo = 2,
        ciao = 2,
    },
    ptBR = {
        para = 2,
        uma = 1,
        com = 1,
        ["não"] = 2,
        nao = 2,
        procuro = 3,
        obrigado = 3,
        grupo = 2,
        ["obrigada"] = 2,
    },
}

-- Distinctive lowercase trigrams for Latin-script languages.
local TRIGRAMS = {
    enUS = { the = 2, ing = 2, ["and"] = 2, ["for"] = 1, you = 1, tha = 1, her = 1 },
    deDE = { sch = 3, ung = 2, cht = 2, ein = 1, ich = 2, und = 2, die = 1, fur = 2 },
    esES = { que = 2, cio = 2, ion = 2, los = 2, par = 2, ara = 1 },
    esMX = { que = 2, cio = 2, ion = 2, los = 2, par = 2, ara = 1 },
    frFR = { les = 2, que = 1, est = 1, our = 2, ais = 2, eur = 1 },
    itIT = { che = 2, zio = 2, gli = 2, per = 2, one = 1 },
    ptBR = { cao = 3, nao = 2, que = 1, par = 1 },
}

local SCRIPT_LANGUAGE = {
    cyrillic = "ruRU",
    hangul = "koKR",
    han = "zhCN",
    kana = "zhCN", -- not Japanese; treat as CJK-adjacent fallback
}

local LATIN = { "enUS", "deDE", "esES", "esMX", "frFR", "itIT", "ptBR" }

local function scoreWords(tokens, code)
    local list = WORDS[code]
    if not list then
        return 0
    end
    local score = 0
    for i = 1, #tokens do
        local w = tokens[i]
        if not IGNORE[w] and not w:match("^{l%d+}$") then
            score = score + (list[w] or 0)
        end
    end
    return score
end

local function scoreTrigrams(normalized, code)
    local list = TRIGRAMS[code]
    if not list then
        return 0
    end
    local score, i = 0, 1
    local U = ns.UTF8
    -- Walk the string as bytes for ASCII-heavy WoW chat; fall back to UTF-8 chars.
    local chars = {}
    while true do
        local cp
        cp, i = U.Next(normalized, i)
        if not cp then
            break
        end
        if U.IsLetter(cp) then
            chars[#chars + 1] = U.Char(cp)
        else
            chars[#chars + 1] = " "
        end
    end
    for n = 1, #chars - 2 do
        local tri = chars[n] .. chars[n + 1] .. chars[n + 2]
        score = score + (list[tri] or 0)
    end
    return score
end

local function dominantScript(text)
    local counts = { latin = 0, cyrillic = 0, hangul = 0, han = 0, kana = 0 }
    local U = ns.UTF8
    local i, letters = 1, 0
    while true do
        local cp
        cp, i = U.Next(text, i)
        if not cp then
            break
        end
        local script = U.Script(cp)
        if counts[script] then
            counts[script] = counts[script] + 1
            letters = letters + 1
        end
    end
    if letters == 0 then
        return nil, 0
    end
    local best, bestN = nil, 0
    for script, n in pairs(counts) do
        if n > bestN then
            best, bestN = script, n
        end
    end
    return best, bestN / letters
end

--- Detects the language of already-normalized chat text.
---@param normalized string
---@param tokens table|nil
---@return string|nil language
---@return number confidence 0..1
function Detect.Identify(normalized, tokens)
    if not normalized or normalized == "" then
        return nil, 0
    end
    tokens = tokens or {}

    local script, share = dominantScript(normalized)
    if script and script ~= "latin" and share >= 0.4 then
        return SCRIPT_LANGUAGE[script], share
    end

    local bestCode, bestScore, second = nil, 0, 0
    for i = 1, #LATIN do
        local code = LATIN[i]
        local score = scoreWords(tokens, code) * 3 + scoreTrigrams(normalized, code)
        if score > bestScore then
            second = bestScore
            bestScore = score
            bestCode = code
        elseif score > second then
            second = score
        end
    end

    if not bestCode or bestScore <= 0 then
        return nil, 0
    end
    local confidence = bestScore / (bestScore + second + 1)
    return bestCode, confidence
end

--- Convenience: normalize then identify.
---@param text string
---@return string|nil language
---@return number confidence
---@return table norm
function Detect.Of(text)
    local norm = ns.Normalize.Run(text)
    local lang, confidence = Detect.Identify(norm.normalized, norm.tokens)
    return lang, confidence, norm
end
