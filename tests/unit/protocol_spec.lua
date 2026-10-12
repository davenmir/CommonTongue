local loader = require("tests.helpers.loader")

local FILES = {
    "Core/Init.lua",
    "Core/UTF8.lua",
    "Engine/Data.lua",
    "Engine/Params.lua",
    "Data/Phrases.lua",
    "Data/enUS/Phrases.lua",
    "Comm/Protocol.lua",
}

describe("Protocol", function()
    local ns, Protocol

    before_each(function()
        ns = loader.load({ files = FILES })
        Protocol = ns.Protocol
    end)

    it("round-trips a parameterized LFG phrase", function()
        local params = { roles = { "tank", "healer" }, activity = "+10" }
        local visible = "LFM tank and healer for +10"
        local encoded = Protocol.EncodePhrase("LFM_ROLES", params, visible)
        local decoded = Protocol.Decode(encoded)
        assert.are.equal(Protocol.KIND_PHRASE, decoded.kind)
        assert.are.equal("LFM_ROLES", decoded.id)
        assert.are.same({ "tank", "healer" }, decoded.params.roles)
        assert.are.equal("+10", decoded.params.activity)
        assert.are.equal(Protocol.Corr(visible), decoded.corr)
    end)

    it("round-trips a pull-in number and a courtesy phrase with no params", function()
        local pull = Protocol.Decode(Protocol.EncodePhrase("PULL_IN", {
            seconds = { value = 10, plus = false },
        }, "pull in 10"))
        assert.are.equal(10, pull.params.seconds.value)
        assert.is_false(pull.params.seconds.plus)

        local thanks = Protocol.Decode(Protocol.EncodePhrase("THANKS", {}, "thanks"))
        assert.are.equal("THANKS", thanks.id)
        assert.are.same({}, thanks.params)
    end)

    it("percent-encodes separators inside activity text", function()
        local encoded = Protocol.EncodePhrase("LFG_ACTIVITY", {
            activity = "key | foo;bar=1",
        }, "LFG key | foo;bar=1")
        assert.is_nil(encoded:find("foo;bar", 1, true))
        local decoded = Protocol.Decode(encoded)
        assert.are.equal("key | foo;bar=1", decoded.params.activity)
    end)

    it("encodes a hello and ignores other versions and garbage", function()
        local hello = Protocol.Decode(Protocol.EncodeHello("0.4.0-dev"))
        assert.are.equal(Protocol.KIND_HELLO, hello.kind)
        assert.are.equal("0.4.0-dev", hello.version)
        assert.is_nil(Protocol.Decode("2|P|THANKS||deadbeef"))
        assert.is_nil(Protocol.Decode("not a payload"))
        assert.is_nil(Protocol.Decode(""))
        assert.is_nil(Protocol.Decode(nil))
    end)

    it("is stable for the same visible string", function()
        assert.are.equal(Protocol.Corr("Danke"), Protocol.Corr("Danke"))
        assert.are_not.equal(Protocol.Corr("Danke"), Protocol.Corr("thanks"))
    end)
end)
