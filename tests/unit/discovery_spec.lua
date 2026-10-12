local loader = require("tests.helpers.loader")

describe("Discovery", function()
    local ns, state

    before_each(function()
        ns, state = loader.login()
        state.comms = {}
    end)

    it("announces a hello when grouped and throttles repeats", function()
        state.inGroup = true
        assert.is_true(ns.Discovery.Announce())
        assert.are.equal(1, #state.comms)
        local hello = ns.Protocol.Decode(state.comms[1].text)
        assert.are.equal("H", hello.kind)
        assert.are.equal("1.2.3", hello.version)
        assert.are.equal("PARTY", state.comms[1].dist)
        assert.is_false(ns.Discovery.Announce())
        state.time = state.time + 6
        assert.is_true(ns.Discovery.Announce())
    end)

    it("does not announce while solo or in lockdown", function()
        assert.is_false(ns.Discovery.Announce())
        state.inGroup = true
        state.lockdown = true
        assert.is_false(ns.Discovery.Announce())
    end)

    it("uses INSTANCE_CHAT for instance groups and RAID for raids", function()
        state.inGroup = true
        state.inInstanceGroup = true
        ns.Discovery.Announce()
        assert.are.equal("INSTANCE_CHAT", state.comms[1].dist)
        state.time = state.time + 6
        state.inInstanceGroup = false
        state.inRaid = true
        ns.Discovery.Announce()
        assert.are.equal("RAID", state.comms[2].dist)
    end)

    it("records peers from hello messages", function()
        local hello = ns.Protocol.EncodeHello("0.4.0-dev")
        state.receiveComm("CTongue", hello, "PARTY", "Buddy")
        local peer = ns.Discovery.Get("Buddy")
        assert.are.equal("0.4.0-dev", peer.version)
    end)
end)
