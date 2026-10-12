local loader = require("tests.helpers.loader")

describe("Composer", function()
    local ns, state

    before_each(function()
        ns, state = loader.login({ locale = "enUS" })
        ns.DB:Profile().translateSelf = true
    end)

    it("parses typed fields into phrase params", function()
        local params = ns.Composer.ParamsFromFields("LFM_ROLES", {
            roles = "tank, healer",
            activity = "+10",
        })
        assert.are.same({ "tank", "healer" }, params.roles)
        assert.are.equal("+10", params.activity)
        local pull = ns.Composer.ParamsFromFields("PULL_IN", { seconds = "10" })
        assert.are.equal(10, pull.seconds.value)
        assert.is_nil(ns.Composer.ParamsFromFields("PULL_IN", { seconds = "" }))
    end)

    it("sends visible English text and a protocol payload on party chat", function()
        local ok = ns.Composer.Send("THANKS", {}, "PARTY")
        assert.is_true(ok)
        assert.are.equal("thanks", state.chatSent[1].text)
        assert.are.equal("PARTY", state.chatSent[1].chatType)
        assert.are.equal(1, #state.comms)
        assert.are.equal("PARTY", state.comms[1].dist)
        local decoded = ns.Protocol.Decode(state.comms[1].text)
        assert.are.equal("THANKS", decoded.id)
    end)

    it("sends SAY without an addon message but still correlates locally", function()
        ns.DB:Profile().targetLanguage = "deDE"
        ns.Composer.Send("THANKS", {}, "SAY")
        assert.are.equal("thanks", state.chatSent[1].text)
        assert.are.equal(0, #state.comms)
        local out = ns.ChatFilter.Process("thanks", "Tester", "CHAT_MSG_SAY")
        assert.truthy(out)
        assert.truthy(out:find("Danke", 1, true))
        assert.truthy(out:find("[CT→de]", 1, true))
    end)

    it("rewrites own party chat via the local correlate echo", function()
        ns.DB:Profile().targetLanguage = "deDE"
        ns.Composer.Send("THANKS", {}, "PARTY")
        local out = ns.ChatFilter.Process("thanks", "Tester", "CHAT_MSG_PARTY")
        assert.truthy(out)
        assert.truthy(out:find("Danke", 1, true))
        assert.truthy(out:find("[CT→de]", 1, true))
    end)

    it("refuses to send during lockdown", function()
        state.lockdown = true
        local ok, reason = ns.Composer.Send("THANKS", {}, "PARTY")
        assert.is_false(ok)
        assert.are.equal("lockdown", reason)
        assert.are.equal(0, #state.chatSent)
        assert.are.equal(0, #state.comms)
    end)

    it("opens an AceGUI frame from /ct compose", function()
        ns.Slash.Handle("compose")
        assert.truthy(ns.Composer.frame)
        assert.are.equal("CommonTongue phrases", ns.Composer.frame.title)
    end)
end)
