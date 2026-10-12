local _, ns = ...
local UTF8 = ns:NewModule("UTF8")

local byte, char, sub = string.byte, string.char, string.sub
local floor = math.floor

local REPLACEMENT = 0xFFFD

local function isContinuation(b)
    return b and b >= 0x80 and b < 0xC0
end

--- Returns the code point at byte index i and the next byte index.
--- Invalid sequences become U+FFFD and consume one byte.
---@param s string
---@param i number
---@return number|nil codepoint
---@return number|nil nextIndex
function UTF8.Next(s, i)
    local b1 = byte(s, i)
    if not b1 then
        return nil
    end
    if b1 < 0x80 then
        return b1, i + 1
    end
    if b1 < 0xC0 then
        return REPLACEMENT, i + 1
    end
    if b1 < 0xE0 then
        local b2 = byte(s, i + 1)
        if not isContinuation(b2) then
            return REPLACEMENT, i + 1
        end
        local cp = (b1 - 0xC0) * 0x40 + (b2 - 0x80)
        if cp < 0x80 then
            return REPLACEMENT, i + 2
        end
        return cp, i + 2
    end
    if b1 < 0xF0 then
        local b2, b3 = byte(s, i + 1), byte(s, i + 2)
        if not isContinuation(b2) or not isContinuation(b3) then
            return REPLACEMENT, i + 1
        end
        local cp = (b1 - 0xE0) * 0x1000 + (b2 - 0x80) * 0x40 + (b3 - 0x80)
        if cp < 0x800 then
            return REPLACEMENT, i + 3
        end
        return cp, i + 3
    end
    if b1 < 0xF8 then
        local b2, b3, b4 = byte(s, i + 1), byte(s, i + 2), byte(s, i + 3)
        if not isContinuation(b2) or not isContinuation(b3) or not isContinuation(b4) then
            return REPLACEMENT, i + 1
        end
        local cp = (b1 - 0xF0) * 0x40000 + (b2 - 0x80) * 0x1000 + (b3 - 0x80) * 0x40 + (b4 - 0x80)
        if cp < 0x10000 or cp > 0x10FFFF then
            return REPLACEMENT, i + 4
        end
        return cp, i + 4
    end
    return REPLACEMENT, i + 1
end

--- Iterates (byteIndex, codepoint) over s.
function UTF8.Codes(s)
    local i = 1
    return function()
        local cp
        local start = i
        cp, i = UTF8.Next(s, i)
        if cp then
            return start, cp
        end
    end
end

---@param s string
---@return number
function UTF8.Len(s)
    local n, i = 0, 1
    while true do
        local cp
        cp, i = UTF8.Next(s, i)
        if not cp then
            return n
        end
        n = n + 1
    end
end

--- Encodes a code point as UTF-8 bytes.
---@param cp number
---@return string
function UTF8.Char(cp)
    if cp < 0x80 then
        return char(cp)
    end
    if cp < 0x800 then
        return char(0xC0 + floor(cp / 0x40), 0x80 + (cp % 0x40))
    end
    if cp < 0x10000 then
        return char(0xE0 + floor(cp / 0x1000), 0x80 + (floor(cp / 0x40) % 0x40), 0x80 + (cp % 0x40))
    end
    return char(
        0xF0 + floor(cp / 0x40000),
        0x80 + (floor(cp / 0x1000) % 0x40),
        0x80 + (floor(cp / 0x40) % 0x40),
        0x80 + (cp % 0x40)
    )
end

--- Truncates to at most maxCodepoints, never splitting a code point.
---@param s string
---@param maxCodepoints number
---@return string
function UTF8.Truncate(s, maxCodepoints)
    if maxCodepoints <= 0 then
        return ""
    end
    local n, i = 0, 1
    while true do
        local cp, nextIndex = UTF8.Next(s, i)
        if not cp then
            return s
        end
        n = n + 1
        if n > maxCodepoints then
            return sub(s, 1, i - 1)
        end
        i = nextIndex
    end
end

--- Script family used by the language detector.
---@param cp number
---@return string "latin"|"cyrillic"|"hangul"|"han"|"kana"|"other"
function UTF8.Script(cp)
    if
        (cp >= 0x0041 and cp <= 0x024F)
        or (cp >= 0x1E00 and cp <= 0x1EFF)
        or (cp >= 0x2C60 and cp <= 0x2C7F)
    then
        return "latin"
    end
    if cp >= 0x0400 and cp <= 0x04FF then
        return "cyrillic"
    end
    if (cp >= 0xAC00 and cp <= 0xD7AF) or (cp >= 0x1100 and cp <= 0x11FF) then
        return "hangul"
    end
    if (cp >= 0x3040 and cp <= 0x30FF) or (cp >= 0x31F0 and cp <= 0x31FF) then
        return "kana"
    end
    if
        (cp >= 0x4E00 and cp <= 0x9FFF)
        or (cp >= 0x3400 and cp <= 0x4DBF)
        or (cp >= 0xF900 and cp <= 0xFAFF)
    then
        return "han"
    end
    return "other"
end

---@param cp number
---@return boolean
function UTF8.IsLetter(cp)
    local script = UTF8.Script(cp)
    if script ~= "other" then
        return true
    end
    return (cp >= 0x61 and cp <= 0x7A) or (cp >= 0x41 and cp <= 0x5A)
end

--- Lowercases ASCII and common Latin-1 letters. Leaves CJK/Hangul/Cyrillic as-is
--- except Cyrillic A-Ya (U+0410-042F → U+0430-044F).
---@param cp number
---@return number
function UTF8.LowerCode(cp)
    if cp >= 0x41 and cp <= 0x5A then
        return cp + 0x20
    end
    if cp >= 0xC0 and cp <= 0xD6 then
        return cp + 0x20
    end
    if cp >= 0xD8 and cp <= 0xDE then
        return cp + 0x20
    end
    if cp >= 0x0410 and cp <= 0x042F then
        return cp + 0x20
    end
    return cp
end

---@param s string
---@return string
function UTF8.Lower(s)
    local out, n = {}, 0
    local i = 1
    while true do
        local cp
        cp, i = UTF8.Next(s, i)
        if not cp then
            break
        end
        n = n + 1
        out[n] = UTF8.Char(UTF8.LowerCode(cp))
    end
    return table.concat(out)
end

-- Diacritics → ASCII base letters. Chat on EU realms is often typed on an
-- English keyboard ("adios", "fur"). Matching must tolerate that; renders keep
-- the accented form from the language pack.
local FOLD = {
    [0x00DF] = "ss", -- ß
    [0x00E6] = "ae", -- æ
    [0x00E7] = "c", -- ç
    [0x00F0] = "d", -- ð
    [0x00F1] = "n", -- ñ
    [0x00F8] = "o", -- ø
    [0x00FE] = "t", -- þ
    [0x00FF] = "y", -- ÿ
    [0x0153] = "oe", -- œ
    [0x0142] = "l", -- ł
}

local function fillFold(from, to, base)
    for cp = from, to do
        FOLD[cp] = base
    end
end

fillFold(0x00E0, 0x00E5, "a") -- à á â ã ä å
fillFold(0x00E8, 0x00EB, "e") -- è é ê ë
fillFold(0x00EC, 0x00EF, "i") -- ì í î ï
fillFold(0x00F2, 0x00F6, "o") -- ò ó ô õ ö
fillFold(0x00F9, 0x00FC, "u") -- ù ú û ü
FOLD[0x00FD] = "y" -- ý

-- Latin Extended-A lowercase letters used in EU locales (odd code points).
local EXTENDED_A = {
    [0x0101] = "a",
    [0x0103] = "a",
    [0x0105] = "a",
    [0x0107] = "c",
    [0x010D] = "c",
    [0x0111] = "d",
    [0x0113] = "e",
    [0x0119] = "e",
    [0x011B] = "e",
    [0x011F] = "g",
    [0x012B] = "i",
    [0x0131] = "i",
    [0x0144] = "n",
    [0x014D] = "o",
    [0x0151] = "o",
    [0x0159] = "r",
    [0x015B] = "s",
    [0x0161] = "s",
    [0x016B] = "u",
    [0x0171] = "u",
    [0x017A] = "z",
    [0x017C] = "z",
    [0x017E] = "z",
}
for cp, base in pairs(EXTENDED_A) do
    FOLD[cp] = base
end

--- Lowercases then strips Latin diacritics. Combining marks are dropped.
---@param cp number
---@return string
function UTF8.FoldCode(cp)
    cp = UTF8.LowerCode(cp)
    if cp >= 0x0300 and cp <= 0x036F then
        return ""
    end
    return FOLD[cp] or UTF8.Char(cp)
end

---@param s string
---@return string
function UTF8.Fold(s)
    local out, n = {}, 0
    local i = 1
    while true do
        local cp
        cp, i = UTF8.Next(s, i)
        if not cp then
            break
        end
        n = n + 1
        out[n] = UTF8.FoldCode(cp)
    end
    return table.concat(out)
end
