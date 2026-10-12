local loader = require("tests.helpers.loader")

local CORE = { "Core/Init.lua", "Core/Compat.lua", "Core/UTF8.lua" }

describe("UTF8", function()
    local UTF8

    before_each(function()
        local ns = loader.load({ files = CORE })
        UTF8 = ns.UTF8
    end)

    it("counts ASCII and multibyte code points", function()
        assert.are.equal(5, UTF8.Len("hello"))
        assert.are.equal(6, UTF8.Len("Danke!"))
        assert.are.equal(6, UTF8.Len("привет"))
        assert.are.equal(2, UTF8.Len("坦克"))
        assert.are.equal(2, UTF8.Len("탱커"))
    end)

    it("iterates without splitting a code point", function()
        local cps = {}
        for _, cp in UTF8.Codes("über") do
            cps[#cps + 1] = cp
        end
        assert.are.equal(4, #cps)
        assert.are.equal(0x00FC, cps[1]) -- ü
    end)

    it("truncates on a code-point boundary", function()
        assert.are.equal("при", UTF8.Truncate("привет", 3))
        assert.are.equal("坦", UTF8.Truncate("坦克", 1))
        assert.are.equal("", UTF8.Truncate("hello", 0))
        assert.are.equal("hello", UTF8.Truncate("hello", 10))
    end)

    it("classifies scripts", function()
        assert.are.equal("latin", UTF8.Script(0x41))
        assert.are.equal("latin", UTF8.Script(0x00FC))
        assert.are.equal("cyrillic", UTF8.Script(0x043F))
        assert.are.equal("hangul", UTF8.Script(0xD0F1))
        assert.are.equal("han", UTF8.Script(0x5766))
        assert.are.equal("other", UTF8.Script(0x20))
    end)

    it("lowercases Latin and Cyrillic without touching CJK", function()
        assert.are.equal("hello", UTF8.Lower("HeLLo"))
        assert.are.equal("über", UTF8.Lower("Über"))
        assert.are.equal("привет", UTF8.Lower("Привет"))
        assert.are.equal("坦克", UTF8.Lower("坦克"))
    end)

    it("round-trips Char and Next", function()
        local encoded = UTF8.Char(0x1F4A9)
        local cp, nextIndex = UTF8.Next(encoded, 1)
        assert.are.equal(0x1F4A9, cp)
        assert.are.equal(#encoded + 1, nextIndex)
    end)
end)
