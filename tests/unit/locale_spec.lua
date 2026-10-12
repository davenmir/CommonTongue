local lfs = require("lfs")
local loader = require("tests.helpers.loader")

local function luaFiles(dir, out)
    for entry in lfs.dir(dir) do
        if entry ~= "." and entry ~= ".." and entry ~= "Libs" then
            local path = dir .. "/" .. entry
            local mode = lfs.attributes(path, "mode")
            if mode == "directory" then
                luaFiles(path, out)
            elseif entry:match("%.lua$") then
                out[#out + 1] = path
            end
        end
    end
    return out
end

describe("Locales", function()
    it("defines every L[...] key used in the addon in enUS", function()
        local ns = loader.load()
        local defined = rawget
        local missing = {}

        for _, path in ipairs(luaFiles("CommonTongue", {})) do
            local f = assert(io.open(path, "rb"))
            local source = f:read("*a")
            f:close()
            for key in source:gmatch('L%["(.-)"%]') do
                if defined(ns.L, key) == nil then
                    missing[#missing + 1] = path .. ": " .. key
                end
            end
        end

        assert.are.same({}, missing)
    end)
end)
