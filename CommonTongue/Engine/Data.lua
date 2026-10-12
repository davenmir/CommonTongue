local _, ns = ...
local Data = ns:NewModule("Data")

local catalog = {}
local languages = {}
local indexes = {}

---@param spec table<string, { params?: table<string, string> }>
function Data.RegisterPhrases(spec)
    for id, def in pairs(spec) do
        catalog[id] = def
    end
end

---@param code string
---@param pack table { reviewed: boolean, phrases: table }
function Data.RegisterLanguage(code, pack)
    languages[code] = pack
    indexes[code] = nil
end

---@param id string
---@return table|nil
function Data.GetPhrase(id)
    return catalog[id]
end

---@param code string
---@return table|nil
function Data.GetLanguage(code)
    return languages[code]
end

---@return table<string, table>
function Data.Catalog()
    return catalog
end

---@return table<string, table>
function Data.Languages()
    return languages
end

local function foldLit(token)
    local U = ns.UTF8
    if U and U.Fold then
        return U.Fold(token)
    end
    return token
end

local function parsePattern(pattern)
    local parts = {}
    for token in pattern:gmatch("%S+") do
        local slot = token:match("^{(%w+)}$")
        if slot then
            parts[#parts + 1] = { slot = slot }
        else
            parts[#parts + 1] = { lit = foldLit(token) }
        end
    end
    return parts
end

--- First-token index, built once per language.
---@param code string
---@return table
function Data.Index(code)
    local existing = indexes[code]
    if existing then
        return existing
    end
    local pack = languages[code]
    local index = { byFirst = {}, startsWithSlot = {} }
    if not pack then
        indexes[code] = index
        return index
    end
    for id, phrase in pairs(pack.phrases or {}) do
        local def = catalog[id]
        if def then
            for _, pattern in ipairs(phrase.match or {}) do
                local parts = parsePattern(pattern)
                local entry = { id = id, parts = parts, pattern = pattern }
                if parts[1] and parts[1].lit then
                    local bucket = index.byFirst[parts[1].lit]
                    if not bucket then
                        bucket = {}
                        index.byFirst[parts[1].lit] = bucket
                    end
                    bucket[#bucket + 1] = entry
                else
                    index.startsWithSlot[#index.startsWithSlot + 1] = entry
                end
            end
        end
    end
    local function longerFirst(a, b)
        if #a.parts ~= #b.parts then
            return #a.parts > #b.parts
        end
        return #a.pattern > #b.pattern
    end
    for _, bucket in pairs(index.byFirst) do
        table.sort(bucket, longerFirst)
    end
    table.sort(index.startsWithSlot, longerFirst)
    indexes[code] = index
    return index
end

function Data.ClearIndexes()
    wipe(indexes)
end
