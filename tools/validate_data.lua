-- Validates phrase catalog and language packs. Run: lua5.1 tools/validate_data.lua
local ROOT = "CommonTongue/"

local ns = {
    modules = {},
    moduleOrder = {},
}
function ns:NewModule(name)
    local module = { name = name }
    self[name] = module
    return module
end

_G.wipe = _G.wipe
    or function(t)
        for k in pairs(t) do
            t[k] = nil
        end
        return t
    end

local files = {
    "Engine/Data.lua",
    "Data/Phrases.lua",
    "Data/enUS/Phrases.lua",
    "Data/deDE/Phrases.lua",
    "Data/esES/Phrases.lua",
}

for i = 1, #files do
    local chunk = assert(loadfile(ROOT .. files[i]))
    chunk("CommonTongue", ns)
end

local errors = {}
local function fail(msg)
    errors[#errors + 1] = msg
end

local function validUtf8(s)
    local i, n = 1, #s
    while i <= n do
        local c = s:byte(i)
        local need = c < 0x80 and 1 or c < 0xE0 and 2 or c < 0xF0 and 3 or c < 0xF8 and 4
        if not need or i + need - 1 > n then
            return false
        end
        for j = 1, need - 1 do
            local b = s:byte(i + j)
            if not b or b < 0x80 or b >= 0xC0 then
                return false
            end
        end
        i = i + need
    end
    return true
end

local catalog = ns.Data.Catalog()
if not next(catalog) then
    fail("catalog is empty")
end

for id, def in pairs(catalog) do
    if type(id) ~= "string" or not id:match("^[%u%d_]+$") then
        fail("bad phrase id: " .. tostring(id))
    end
    if def.params then
        for name, typeName in pairs(def.params) do
            if type(name) ~= "string" or type(typeName) ~= "string" then
                fail(id .. " has a bad param")
            end
        end
    end
end

local seenPattern = {}
for code, pack in pairs(ns.Data.Languages()) do
    if type(pack.reviewed) ~= "boolean" then
        fail(code .. ": reviewed must be boolean")
    end
    for id, phrase in pairs(pack.phrases or {}) do
        if not catalog[id] then
            fail(code .. ": unknown phrase " .. id)
        end
        if type(phrase.render) ~= "string" or phrase.render == "" then
            fail(code .. " " .. id .. ": missing render")
        elseif not validUtf8(phrase.render) then
            fail(code .. " " .. id .. ": render is not valid UTF-8")
        end
        local allowed = catalog[id].params or {}
        for slot in phrase.render:gmatch("{(%w+)}") do
            if not allowed[slot] then
                fail(code .. " " .. id .. ": render has unknown slot {" .. slot .. "}")
            end
        end
        if not phrase.match or #phrase.match == 0 then
            fail(code .. " " .. id .. ": no match patterns")
        end
        for _, pattern in ipairs(phrase.match) do
            if pattern ~= pattern:lower() then
                fail(code .. " " .. id .. ": pattern is not lowercase: " .. pattern)
            end
            if not validUtf8(pattern) then
                fail(code .. " " .. id .. ": pattern is not valid UTF-8")
            end
            local key = code .. "\0" .. pattern
            if seenPattern[key] then
                fail(code .. ": duplicate pattern '" .. pattern .. "'")
            end
            seenPattern[key] = true
            for slot in pattern:gmatch("{(%w+)}") do
                if not allowed[slot] then
                    fail(code .. " " .. id .. ": match has unknown slot {" .. slot .. "}")
                end
            end
        end
    end
end

if #errors > 0 then
    io.stderr:write(table.concat(errors, "\n") .. "\n")
    os.exit(1)
end
print("phrase data ok")
