local loader = require("tests.helpers.loader")

describe("Correlate", function()
    local ns, state

    before_each(function()
        ns, state = loader.login({ locale = "enUS" })
        ns.Correlate.Clear()
    end)

    it("matches a payload to the same sender and visible text", function()
        local visible = "LFM tank and healer for +10"
        local payload = ns.Protocol.Decode(
            ns.Protocol.EncodePhrase("LFM_ROLES", {
                roles = { "tank", "healer" },
                activity = "+10",
            }, visible)
        )
        ns.Correlate.Put("Other-Realm", payload)
        local hit = ns.Correlate.Take("Other", visible)
        assert.are.equal("LFM_ROLES", hit.id)
        assert.is_nil(ns.Correlate.Take("Other", visible))
    end)

    it("does not match a different sender or a different line", function()
        local visible = "thanks"
        local payload = ns.Protocol.Decode(ns.Protocol.EncodePhrase("THANKS", {}, visible))
        ns.Correlate.Put("Alice", payload)
        assert.is_nil(ns.Correlate.Take("Bob", visible))
        assert.is_nil(ns.Correlate.Take("Alice", "ty"))
        assert.are.equal("THANKS", ns.Correlate.Take("Alice", visible).id)
    end)

    it("expires payloads after the correlation window", function()
        local visible = "ready"
        local payload = ns.Protocol.Decode(ns.Protocol.EncodePhrase("READY", {}, visible))
        ns.Correlate.Put("Other", payload)
        state.time = state.time + 4
        assert.is_nil(ns.Correlate.Take("Other", visible))
    end)
end)
