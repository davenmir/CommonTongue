local loader = require("tests.helpers.loader")

describe("Languages", function()
    local Languages

    before_each(function()
        local ns = loader.load({
            files = { "Core/Init.lua", "Core/Compat.lua", "Engine/Languages.lua" },
        })
        Languages = ns.Languages
    end)

    it("has a native name for every supported code", function()
        assert.are.equal(11, #Languages.CODES)
        for _, code in ipairs(Languages.CODES) do
            assert.is_string(Languages.NATIVE_NAMES[code], code)
        end
    end)

    it("normalizes client locales", function()
        assert.are.equal("deDE", Languages.Normalize("deDE"))
        assert.are.equal("enUS", Languages.Normalize("enGB"))
        assert.are.equal("ptBR", Languages.Normalize("ptPT"))
        assert.are.equal("enUS", Languages.Normalize("xxXX"))
        assert.are.equal("enUS", Languages.Normalize(nil))
    end)

    it("resolves the target language setting", function()
        assert.are.equal("frFR", Languages.Resolve("auto", "frFR"))
        assert.are.equal("enUS", Languages.Resolve("auto", "enGB"))
        assert.are.equal("koKR", Languages.Resolve("koKR", "frFR"))
        assert.are.equal("frFR", Languages.Resolve("bogus", "frFR"))
    end)
end)
