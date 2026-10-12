local _, ns = ...
local Phrase = ns:NewModule("Phrase")

local function nextLiteral(parts, from)
    for i = from, #parts do
        if parts[i].lit then
            return parts[i].lit
        end
    end
end

local function findToken(tokens, lit, first, last)
    for i = first, last do
        if tokens[i] == lit then
            return i
        end
    end
end

local function allSkip(tokens, first, last)
    if first > last then
        return true
    end
    for i = first, last do
        if not ns.Params.IsSkip(tokens[i]) then
            return false
        end
    end
    return true
end

local function matchParts(tokens, parts, catalogEntry, start)
    local i = start
    local n = #tokens
    local params = {}
    for p = 1, #parts do
        local part = parts[p]
        if part.lit then
            if tokens[i] ~= part.lit then
                return nil
            end
            i = i + 1
        else
            local typeName = (catalogEntry.params or {})[part.slot] or part.slot
            local last = n
            local lit = nextLiteral(parts, p + 1)
            if lit then
                local at = findToken(tokens, lit, i, n)
                if not at then
                    return nil
                end
                last = at - 1
            end
            if i > last and typeName ~= "activity" then
                return nil
            end
            local value, nextI = ns.Params.Parse(typeName, tokens, i, last)
            if not value then
                return nil
            end
            params[part.slot] = value
            i = nextI
        end
    end
    if i <= n and not allSkip(tokens, i, n) then
        return nil
    end
    return params
end

local function tryAt(index, tokens, catalog, start)
    if start > #tokens then
        return nil
    end
    local buckets = { index.byFirst[tokens[start]], index.startsWithSlot }
    for b = 1, #buckets do
        local list = buckets[b]
        if list then
            for e = 1, #list do
                local entry = list[e]
                local def = catalog[entry.id]
                if def then
                    local params = matchParts(tokens, entry.parts, def, start)
                    if params and allSkip(tokens, 1, start - 1) then
                        return { id = entry.id, params = params, pattern = entry.pattern }
                    end
                end
            end
        end
    end
end

local function tryIndex(index, tokens, catalog)
    if #tokens == 0 then
        return nil
    end
    for start = 1, #tokens do
        local hit = tryAt(index, tokens, catalog, start)
        if hit then
            return hit
        end
    end
end

--- Matches normalized tokens against loaded language packs.
---@param tokens table
---@param prefer string|nil language to try first
---@return table|nil { id, params, language, pattern }
function Phrase.Match(tokens, prefer)
    local catalog = ns.Data.Catalog()
    local order = {}
    if prefer and ns.Data.GetLanguage(prefer) then
        order[1] = prefer
    end
    for code in pairs(ns.Data.Languages()) do
        if code ~= prefer then
            order[#order + 1] = code
        end
    end
    for i = 1, #order do
        local code = order[i]
        local hit = tryIndex(ns.Data.Index(code), tokens, catalog)
        if hit then
            hit.language = code
            return hit
        end
    end
end

--- Renders a phrase into locale, leaving unknown slots as `{name}`.
---@param id string
---@param params table
---@param locale string
---@return string|nil
---@return boolean|nil reviewed
function Phrase.Render(id, params, locale)
    local pack = ns.Data.GetLanguage(locale)
    local def = ns.Data.GetPhrase(id)
    if not pack or not def then
        return nil
    end
    local phrase = pack.phrases[id]
    if not phrase or not phrase.render then
        return nil
    end
    local text = phrase.render:gsub("{(%w+)}", function(slot)
        local typeName = (def.params or {})[slot] or slot
        local value = params[slot]
        if value == nil then
            return "{" .. slot .. "}"
        end
        return ns.Params.Format(typeName, value, locale)
    end)
    text = text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    -- Empty activity leaves a dangling preposition: "LFM tank for".
    text = text:gsub(" (%S+)$", function(word)
        if word == "for" or word == "für" or word == "para" then
            return ""
        end
        return " " .. word
    end)
    return text, pack.reviewed == true
end
