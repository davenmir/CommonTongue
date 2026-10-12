local _, ns = ...
local Params = ns:NewModule("Params")

local ROLE_ALIAS = {
    tank = "tank",
    tanks = "tank",
    tanque = "tank",
    tanques = "tank",
    healer = "healer",
    heal = "healer",
    healers = "healer",
    heiler = "healer",
    sanador = "healer",
    sanadores = "healer",
    healz = "healer",
    hps = "healer",
    dps = "dps",
    dd = "dps",
    damage = "dps",
}

local CONNECTOR = {
    y = true,
    e = true,
    et = true,
    und = true,
    ["and"] = true,
    ["/"] = true,
    [","] = true,
    ["+"] = true,
    ["&"] = true,
}

local ROLE_RENDER = {
    enUS = { tank = "tank", healer = "healer", dps = "DPS" },
    deDE = { tank = "Tank", healer = "Heiler", dps = "DPS" },
    esES = { tank = "tanque", healer = "sanador", dps = "DPS" },
    esMX = { tank = "tanque", healer = "sanador", dps = "DPS" },
}

local ROLE_JOIN = {
    enUS = " and ",
    deDE = " und ",
    esES = " y ",
    esMX = " y ",
}

local function splitRoleToken(token)
    local pieces = {}
    for part in token:gmatch("[^/,%+&]+") do
        part = part:match("^%s*(.-)%s*$")
        if part ~= "" then
            pieces[#pieces + 1] = part
        end
    end
    return pieces
end

local function parseRoles(tokens, first, last)
    local roles, seen = {}, {}
    local i = first
    local found = false
    while i <= last do
        local token = tokens[i]
        if CONNECTOR[token] then
            i = i + 1
        else
            local matched = false
            for _, piece in ipairs(splitRoleToken(token)) do
                local role = ROLE_ALIAS[piece]
                if role and not seen[role] then
                    seen[role] = true
                    roles[#roles + 1] = role
                    found = true
                    matched = true
                end
            end
            if not matched then
                break
            end
            i = i + 1
        end
    end
    if not found then
        return nil
    end
    return roles, i
end

local function parseGold(tokens, first, last)
    if first > last then
        return nil
    end
    local token = tokens[first]
    local g, s, c = token:match("^(%d+)g(%d*)s?(%d*)c?$")
    if not g then
        g = token:match("^(%d+)g$")
    end
    if not g then
        return nil
    end
    return { gold = tonumber(g), silver = tonumber(s) or 0, copper = tonumber(c) or 0 }, first + 1
end

local function parseNumber(tokens, first, last)
    if first > last then
        return nil
    end
    local token = tokens[first]
    local plus, n = token:match("^(%+?)(%d+)$")
    if not n then
        return nil
    end
    return { value = tonumber(n), plus = plus == "+" }, first + 1
end

local function parseLink(tokens, first, last)
    if first > last then
        return nil
    end
    local token = tokens[first]
    if not token:match("^{l%d+}$") then
        return nil
    end
    return token, first + 1
end

local function parseActivity(tokens, first, last)
    if first > last then
        return nil
    end
    local parts = {}
    for i = first, last do
        parts[#parts + 1] = tokens[i]
    end
    return table.concat(parts, " "), last + 1
end

local PARSERS = {
    roleList = parseRoles,
    gold = parseGold,
    number = parseNumber,
    link = parseLink,
    item = parseLink,
    activity = parseActivity,
}

--- Parses a typed slot from tokens[first..last].
---@return any value
---@return number|nil nextIndex
function Params.Parse(typeName, tokens, first, last)
    local parser = PARSERS[typeName]
    if not parser then
        return parseActivity(tokens, first, last)
    end
    return parser(tokens, first, last)
end

function Params.Format(typeName, value, locale)
    if typeName == "roleList" then
        local names = ROLE_RENDER[locale] or ROLE_RENDER.enUS
        local join = ROLE_JOIN[locale] or ROLE_JOIN.enUS
        local out = {}
        for i = 1, #value do
            out[i] = names[value[i]] or value[i]
        end
        if #out == 0 then
            return ""
        end
        if #out == 1 then
            return out[1]
        end
        return table.concat(out, join)
    end
    if typeName == "gold" then
        local s = tostring(value.gold) .. "g"
        if value.silver > 0 then
            s = s .. value.silver .. "s"
        end
        return s
    end
    if typeName == "number" then
        if value.plus then
            return "+" .. tostring(value.value)
        end
        return tostring(value.value)
    end
    if typeName == "link" or typeName == "item" then
        return value
    end
    return tostring(value)
end
