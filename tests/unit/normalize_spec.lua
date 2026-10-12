local loader = require("tests.helpers.loader")

local FILES = {
    "Core/Init.lua",
    "Core/Compat.lua",
    "Core/UTF8.lua",
    "Engine/Normalize.lua",
}

describe("Normalize", function()
    local Normalize

    before_each(function()
        local ns = loader.load({ files = FILES })
        ns.Normalize:OnInitialize()
        Normalize = ns.Normalize
    end)

    it("lowercases and trims", function()
        local r = Normalize.Run("  HeLLo There  ")
        assert.are.equal("hello there", r.normalized)
        assert.are.same({ "hello", "there" }, r.tokens)
    end)

    it("strips color codes and keeps the inner text", function()
        local r = Normalize.Run("|cffff0000LFM|r tank")
        assert.are.equal("lfm tank", r.normalized)
    end)

    it("lifts item links into placeholders", function()
        local link = "|Hitem:19019::::::::80:::::|h[Thunderfury]|h"
        local r = Normalize.Run("WTS " .. link .. " 50g")
        assert.are.equal("wts {l1} 50g", r.normalized)
        assert.are.equal(link, r.placeholders[1])
        local restored = Normalize.Restore("WTS {l1} 50g", r.placeholders)
        assert.are.equal("WTS " .. link .. " 50g", restored)
    end)

    it("lifts textures", function()
        local r = Normalize.Run("hi |TInterface\\Icons\\INV_Sword_04:12|t there")
        assert.are.equal("hi {t1} there", r.normalized)
    end)

    it("collapses long letter runs but keeps doubles and digits", function()
        assert.are.equal("heello", Normalize.Run("heeeello").normalized)
        assert.are.equal("ss", Normalize.Run("ss").normalized)
        assert.are.equal("1000g", Normalize.Run("1000g").normalized)
    end)

    it("handles Cyrillic, Hangul and Han", function()
        assert.are.equal("привет", Normalize.Run("Привет").normalized)
        assert.are.equal("탱커", Normalize.Run("탱커").normalized)
        assert.are.equal("坦克", Normalize.Run("坦克").normalized)
    end)
end)
