local loader = require("tests.helpers.loader")

local FILES = {
    "Core/Init.lua",
    "Core/Compat.lua",
    "Core/UTF8.lua",
    "Engine/Normalize.lua",
    "Engine/Detect.lua",
    "Engine/Data.lua",
    "Engine/Params.lua",
    "Engine/Phrase.lua",
    "Data/Phrases.lua",
    "Data/enUS/Phrases.lua",
    "Data/deDE/Phrases.lua",
    "Data/esES/Phrases.lua",
}

describe("Phrase", function()
    local ns, Phrase, Normalize

    before_each(function()
        ns = loader.load({ files = FILES })
        ns.Normalize:OnInitialize()
        Phrase = ns.Phrase
        Normalize = ns.Normalize
    end)

    local function match(text, prefer)
        return Phrase.Match(Normalize.Run(text).tokens, prefer)
    end

    it("matches the documented Spanish LFG line", function()
        local hit = match("LFM Tank y healer para +10", "esES")
        assert.is_not_nil(hit)
        assert.are.equal("LFM_ROLES", hit.id)
        assert.are.same({ "tank", "healer" }, hit.params.roles)
        assert.are.equal("+10", hit.params.activity)
    end)

    it("renders that line into English and German", function()
        local hit = match("LFM Tank y healer para +10", "esES")
        local en = Phrase.Render(hit.id, hit.params, "enUS")
        local de, reviewed = Phrase.Render(hit.id, hit.params, "deDE")
        assert.are.equal("LFM tank and healer for +10", en)
        assert.are.equal("Suche Tank und Heiler für +10", de)
        assert.is_false(reviewed)
    end)

    it("matches Spanish and German lines when accents are omitted", function()
        local bye = match("adios", "esES")
        assert.is_not_nil(bye)
        assert.are.equal("BYE", bye.id)
        local hit = match("Suche Tank und Heiler fur +10", "deDE")
        assert.are.equal("LFM_ROLES", hit.id)
        assert.are.equal("LFM tank and healer for +10", Phrase.Render(hit.id, hit.params, "enUS"))
    end)

    it("matches German LFG into English", function()
        local hit = match("Suche Tank und Heiler für +10", "deDE")
        assert.are.equal("LFM_ROLES", hit.id)
        assert.are.equal("LFM tank and healer for +10", Phrase.Render(hit.id, hit.params, "enUS"))
    end)

    it("matches WTS with a link placeholder", function()
        local norm = Normalize.Run("WTS |Hitem:1|h[Sword]|h 50g")
        local hit = Phrase.Match(norm.tokens, "enUS")
        assert.are.equal("WTS_ITEM_PRICE", hit.id)
        assert.are.equal("{l1}", hit.params.item)
        assert.are.equal(50, hit.params.price.gold)
        local rendered = Phrase.Render(hit.id, hit.params, "deDE")
        assert.are.equal("Verkaufe {l1} 50g", rendered)
        assert.are.equal(
            "Verkaufe |Hitem:1|h[Sword]|h 50g",
            Normalize.Restore(rendered, norm.placeholders)
        )
    end)

    it("matches pull-in with a number", function()
        local hit = match("pull in 10", "enUS")
        assert.are.equal("PULL_IN", hit.id)
        assert.are.equal(10, hit.params.seconds.value)
        assert.are.equal("Pull in 10", Phrase.Render(hit.id, hit.params, "deDE"))
    end)

    it("returns nil for uncovered free text", function()
        assert.is_nil(match("what a beautiful sunset tonight", "enUS"))
    end)

    it("matches conversational role lines with wrappers and punctuation", function()
        local switch = match("hi can you dps instead of healing?", "enUS")
        assert.are.equal("SWITCH_ROLE", switch.id)
        assert.are.same({ "dps" }, switch.params.to)
        assert.are.same({ "healer" }, switch.params.from)
        assert.are.equal(
            "kannst du DPS statt Heiler",
            Phrase.Render(switch.id, switch.params, "deDE")
        )

        local heal = match("I heal", "enUS")
        assert.are.equal("I_AM_ROLE", heal.id)
        assert.are.same({ "healer" }, heal.params.roles)
        assert.are.equal("Ich bin Heiler", Phrase.Render(heal.id, heal.params, "deDE"))

        local am = match("i am a healer", "enUS")
        assert.are.equal("I_AM_ROLE", am.id)
        assert.are.same({ "healer" }, am.params.roles)

        local im = match("I'm a tank", "enUS")
        assert.are.equal("I_AM_ROLE", im.id)
        assert.are.same({ "tank" }, im.params.roles)
    end)

    it("matches informal LFM variants and ignores courtesy leftovers", function()
        local a = match("looking for a healer", "enUS")
        assert.are.equal("LFM_ROLES", a.id)
        assert.are.same({ "healer" }, a.params.roles)
        assert.are.equal("LFM healer", Phrase.Render(a.id, a.params, "enUS"))

        local need = match("need a tank thanks", "enUS")
        assert.are.equal("LFM_ROLES", need.id)
        assert.are.same({ "tank" }, need.params.roles)

        local play = match("can you heal", "enUS")
        assert.are.equal("PLAY_ROLE", play.id)
        assert.are.same({ "healer" }, play.params.roles)
    end)
end)
