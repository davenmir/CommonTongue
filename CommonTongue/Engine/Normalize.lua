local _, ns = ...
local Normalize = ns:NewModule("Normalize")

local UTF8 = nil -- filled in OnInitialize; also resolved lazily for tests

local find, sub, concat = string.find, string.sub, table.concat

local function utf8()
    if not UTF8 then
        UTF8 = ns.UTF8
    end
    return UTF8
end

-- WoW markup we lift out before any language work.
-- Links keep their visible text in a placeholder so the matcher can see {L1}.
local LINK_PATTERN = "|H.-|h.-|h"
local TEXTURE_PATTERN = "|T.-|t"
local ATLAS_PATTERN = "|A.-|a"
local COLOR_OPEN = "|c%x%x%x%x%x%x%x%x"
local COLOR_CLOSE = "|r"

local function nextPlaceholder(kind, store, original)
    local n = #store + 1
    store[n] = original
    return "{" .. kind:lower() .. n .. "}", n
end

--- Collapses runs of the same letter longer than 2 down to 2 (heeeello → heello).
--- Leaves digits and punctuation alone so "1000" and "++" stay intact.
---@param s string
---@return string
local function collapseLetters(s)
    local U = utf8()
    local out, n = {}, 0
    local prev, run = nil, 0
    local i = 1
    while true do
        local cp
        cp, i = U.Next(s, i)
        if not cp then
            break
        end
        if U.IsLetter(cp) and cp == prev then
            run = run + 1
            if run < 2 then
                n = n + 1
                out[n] = U.Char(cp)
            end
        else
            prev = U.IsLetter(cp) and cp or nil
            run = 0
            n = n + 1
            out[n] = U.Char(cp)
        end
    end
    return concat(out)
end

local function stripColors(s)
    s = s:gsub(COLOR_OPEN, "")
    s = s:gsub(COLOR_CLOSE, "")
    -- leftover broken color codes
    s = s:gsub("|c%x+", "")
    return s
end

local function replacePattern(s, pattern, kind, store)
    local out, last = {}, 1
    while true do
        local a, b = find(s, pattern, last)
        if not a then
            out[#out + 1] = sub(s, last)
            break
        end
        out[#out + 1] = sub(s, last, a - 1)
        out[#out + 1] = nextPlaceholder(kind, store, sub(s, a, b))
        last = b + 1
    end
    return concat(out)
end

--- Turns chat text into a matcher-ready form.
---@param text string
---@return table result { original, normalized, tokens, placeholders }
function Normalize.Run(text)
    local placeholders = {}
    local s = text or ""
    s = replacePattern(s, LINK_PATTERN, "L", placeholders)
    s = replacePattern(s, TEXTURE_PATTERN, "T", placeholders)
    s = replacePattern(s, ATLAS_PATTERN, "A", placeholders)
    s = stripColors(s)
    -- leftover pipe sequences that are not markup we understand
    s = s:gsub("|+", "|")
    s = utf8().Lower(s)
    s = collapseLetters(s)
    s = s:gsub("%s+", " ")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")

    local tokens = {}
    for word in s:gmatch("%S+") do
        tokens[#tokens + 1] = word
    end

    return {
        original = text,
        normalized = s,
        tokens = tokens,
        placeholders = placeholders,
    }
end

--- Puts captured markup back into a rendered string (`{L1}` → original link).
---@param text string
---@param placeholders table
---@return string
function Normalize.Restore(text, placeholders)
    if not placeholders then
        return text
    end
    return (
        text:gsub("{([ltaLTA])(%d+)}", function(kind, index)
            return placeholders[tonumber(index)] or ("{" .. kind:lower() .. index .. "}")
        end)
    )
end

function Normalize:OnInitialize()
    UTF8 = ns.UTF8
end
