local loader = require("tests.helpers.loader")

local FILES = {
    "Core/Init.lua",
    "Core/Compat.lua",
    "Core/UTF8.lua",
    "Engine/Normalize.lua",
    "Engine/Detect.lua",
}

describe("Detect", function()
    local Detect

    before_each(function()
        local ns = loader.load({ files = FILES })
        ns.Normalize:OnInitialize()
        Detect = ns.Detect
    end)

    local function lang(text)
        local code, confidence = Detect.Of(text)
        return code, confidence
    end

    it("uses script ranges for non-Latin text", function()
        assert.are.equal("ruRU", lang("привет танк и хил"))
        assert.are.equal("koKR", lang("탱커 구합니다"))
        assert.are.equal("zhCN", lang("坦克 求组"))
    end)

    it("scores Latin languages from distinctive words", function()
        assert.are.equal("esES", lang("LFM Tank y healer para +10"))
        assert.are.equal("deDE", lang("Suche Tank und Heiler für +10"))
        assert.are.equal("enUS", lang("looking for tank and healer for the key"))
        assert.are.equal("frFR", lang("je cherche tank et heal pour +10"))
        assert.are.equal("itIT", lang("cerco tank e heal per +10 grazie"))
        assert.are.equal("ptBR", lang("procuro tank e healer para +10 obrigado"))
    end)

    it("returns no language for empty or slang-only text", function()
        local code, confidence = lang("")
        assert.is_nil(code)
        assert.are.equal(0, confidence)
        code = lang("lfm tank healer dps")
        assert.is_nil(code)
    end)

    it("returns a confidence between 0 and 1", function()
        local _, confidence = lang("Suche Tank und Heiler für die Gruppe")
        assert.is_true(confidence > 0.5)
        assert.is_true(confidence <= 1)
    end)
end)
