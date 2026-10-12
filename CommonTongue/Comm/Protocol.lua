local _, ns = ...
local Protocol = ns:NewModule("Protocol")

local tonumber, tostring, type, pairs = tonumber, tostring, type, pairs
local format, byte, char = string.format, string.byte, string.char

Protocol.PREFIX = "CTongue"
Protocol.VERSION = 1
Protocol.KIND_PHRASE = "P"
Protocol.KIND_HELLO = "H"

local function pctEncode(s)
    return (tostring(s):gsub("[^%w%._%-+,]", function(c)
        return format("%%%02X", byte(c))
    end))
end

local function pctDecode(s)
    return (s:gsub("%%(%x%x)", function(hex)
        return char(tonumber(hex, 16))
    end))
end

local function splitPipe(s)
    local out = {}
    local start = 1
    while true do
        local at = s:find("|", start, true)
        if not at then
            out[#out + 1] = s:sub(start)
            return out
        end
        out[#out + 1] = s:sub(start, at - 1)
        start = at + 1
    end
end

--- djb2-32 of the exact visible chat bytes, 8 lowercase hex digits.
---@param text string
---@return string
function Protocol.Corr(text)
    local h = 5381
    for i = 1, #text do
        h = (h * 33 + byte(text, i)) % 4294967296
    end
    local hex = "0123456789abcdef"
    local out = {}
    for i = 8, 1, -1 do
        local d = h % 16
        out[i] = hex:sub(d + 1, d + 1)
        h = (h - d) / 16
    end
    return table.concat(out)
end

local function encodeValue(typeName, value)
    if typeName == "roleList" then
        return table.concat(value, ",")
    end
    if typeName == "gold" then
        local s = tostring(value.gold) .. "g"
        if value.silver and value.silver > 0 then
            s = s .. tostring(value.silver) .. "s"
        end
        if value.copper and value.copper > 0 then
            s = s .. tostring(value.copper) .. "c"
        end
        return s
    end
    if typeName == "number" then
        if value.plus then
            return "+" .. tostring(value.value)
        end
        return tostring(value.value)
    end
    return tostring(value)
end

local function decodeValue(typeName, raw)
    if typeName == "roleList" then
        local tokens = {}
        for piece in raw:gmatch("[^,]+") do
            tokens[#tokens + 1] = piece
        end
        if #tokens == 0 then
            return nil
        end
        local value = ns.Params.Parse("roleList", tokens, 1, #tokens)
        return value
    end
    if typeName == "gold" or typeName == "number" then
        local value = ns.Params.Parse(typeName, { raw }, 1, 1)
        return value
    end
    return raw
end

---@param params table
---@param id string
---@return string
function Protocol.EncodeParams(id, params)
    if type(params) ~= "table" then
        return ""
    end
    local def = ns.Data.GetPhrase(id)
    local types = (def and def.params) or {}
    local keys = {}
    for key in pairs(params) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    local parts = {}
    for i = 1, #keys do
        local key = keys[i]
        local typeName = types[key] or key
        parts[#parts + 1] = key .. "=" .. pctEncode(encodeValue(typeName, params[key]))
    end
    return table.concat(parts, ";")
end

---@param id string
---@param encoded string
---@return table
function Protocol.DecodeParams(id, encoded)
    local params = {}
    if encoded == nil or encoded == "" then
        return params
    end
    local def = ns.Data.GetPhrase(id)
    local types = (def and def.params) or {}
    for pair in encoded:gmatch("[^;]+") do
        local key, raw = pair:match("^([^=]+)=(.*)$")
        if key then
            local typeName = types[key] or key
            local value = decodeValue(typeName, pctDecode(raw))
            if value ~= nil then
                params[key] = value
            end
        end
    end
    return params
end

---@param id string
---@param params table|nil
---@param visible string
---@return string
function Protocol.EncodePhrase(id, params, visible)
    return table.concat({
        tostring(Protocol.VERSION),
        Protocol.KIND_PHRASE,
        id,
        Protocol.EncodeParams(id, params or {}),
        Protocol.Corr(visible),
    }, "|")
end

---@param addonVersion string
---@return string
function Protocol.EncodeHello(addonVersion)
    return table.concat({
        tostring(Protocol.VERSION),
        Protocol.KIND_HELLO,
        pctEncode(addonVersion or "?"),
    }, "|")
end

--- Parses a payload. Returns nil for garbage or a different major version.
---@param payload string
---@return table|nil
function Protocol.Decode(payload)
    if type(payload) ~= "string" or payload == "" then
        return nil
    end
    local fields = splitPipe(payload)
    local version = tonumber(fields[1])
    local kind = fields[2]
    if version ~= Protocol.VERSION or not kind then
        return nil
    end
    if kind == Protocol.KIND_PHRASE then
        local id, encoded, corr = fields[3], fields[4], fields[5]
        if not id or id == "" or not corr then
            return nil
        end
        return {
            kind = kind,
            id = id,
            params = Protocol.DecodeParams(id, encoded or ""),
            corr = corr,
        }
    end
    if kind == Protocol.KIND_HELLO then
        local addonVersion = fields[3] and pctDecode(fields[3]) or "?"
        return { kind = kind, version = addonVersion }
    end
    return nil
end
