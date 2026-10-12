local loader = require("tests.helpers.loader")

describe("Transport", function()
    local ns, state

    before_each(function()
        ns, state = loader.login()
    end)

    it("registers the CTongue prefix", function()
        assert.is_true(state.prefixes.CTongue)
    end)

    it("maps group chat types to addon distributions and skips SAY", function()
        assert.are.equal("PARTY", ns.Transport.DistForChat("PARTY"))
        assert.are.equal("INSTANCE_CHAT", ns.Transport.DistForChat("INSTANCE"))
        local dist, dest = ns.Transport.DistForChat("WHISPER", "Friend")
        assert.are.equal("WHISPER", dist)
        assert.are.equal("Friend", dest)
        assert.is_nil(ns.Transport.DistForChat("SAY"))
        assert.is_nil(ns.Transport.DistForChat("WHISPER"))
    end)

    it("does not send during lockdown or when protocol is disabled", function()
        state.lockdown = true
        assert.is_false(ns.Transport.Send("1|H|x", "PARTY"))
        state.lockdown = false
        ns.DB:Profile().protocol = false
        assert.is_false(ns.Transport.Send("1|H|x", "PARTY"))
        ns.DB:Profile().protocol = true
        assert.is_true(ns.Transport.Send("1|H|x", "PARTY"))
        assert.are.equal(1, #state.comms)
        assert.are.equal("CTongue", state.comms[1].prefix)
        assert.are.equal("PARTY", state.comms[1].dist)
    end)

    it("stores incoming phrase payloads and notes the sender", function()
        local visible = "thanks"
        local payload = ns.Protocol.EncodePhrase("THANKS", {}, visible)
        state.receiveComm("CTongue", payload, "PARTY", "Other-Realm")
        assert.truthy(ns.Discovery.Get("Other"))
        local hit = ns.Correlate.Take("Other", visible)
        assert.are.equal("THANKS", hit.id)
    end)

    it("ignores secret addon messages", function()
        local secret = loader.stubs.secret("comm")
        state.secrets[secret] = true
        state.receiveComm("CTongue", secret, "PARTY", "Other")
        assert.is_nil(ns.Discovery.Get("Other"))
    end)
end)
