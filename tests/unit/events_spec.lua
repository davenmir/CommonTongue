local loader = require("tests.helpers.loader")

local CORE = { "Core/Init.lua", "Core/Compat.lua", "Core/Events.lua" }

describe("Events", function()
    local ns, state, Events, owner

    before_each(function()
        ns, state = loader.load({ files = CORE })
        Events = ns.Events
        owner = { name = "Owner" }
    end)

    local function eventFrame()
        return state.frames[1]
    end

    it("dispatches to a function with owner, event and payload", function()
        local got
        Events:Register("TEST_EVENT", owner, function(self, event, a, b)
            got = { self, event, a, b }
        end)

        state.fire("TEST_EVENT", 1, "two")

        assert.are.same({ owner, "TEST_EVENT", 1, "two" }, got)
    end)

    it("dispatches to a method by name", function()
        function owner:OnTest(_, value)
            self.value = value
        end
        Events:Register("TEST_EVENT", owner, "OnTest")

        state.fire("TEST_EVENT", 42)

        assert.are.equal(42, owner.value)
    end)

    it("registers the frame event once and unregisters it with the last handler", function()
        local other = {}
        Events:Register("TEST_EVENT", owner, function() end)
        Events:Register("TEST_EVENT", other, function() end)
        assert.is_true(eventFrame():IsEventRegistered("TEST_EVENT"))

        Events:Unregister("TEST_EVENT", owner)
        assert.is_true(eventFrame():IsEventRegistered("TEST_EVENT"))
        assert.is_true(Events:IsRegistered("TEST_EVENT", other))

        Events:Unregister("TEST_EVENT", other)
        assert.is_false(eventFrame():IsEventRegistered("TEST_EVENT"))
        assert.is_false(Events:IsRegistered("TEST_EVENT"))
    end)

    it("rejects double registration and non-functions", function()
        Events:Register("TEST_EVENT", owner, function() end)
        assert.has_error(function()
            Events:Register("TEST_EVENT", owner, function() end)
        end)
        assert.has_error(function()
            Events:Register("OTHER_EVENT", owner, "MissingMethod")
        end)
    end)

    it("lets a handler unregister itself mid-dispatch without skipping others", function()
        local second = {}
        local calls = 0
        Events:Register("TEST_EVENT", owner, function(self)
            calls = calls + 1
            Events:Unregister("TEST_EVENT", self)
        end)
        Events:Register("TEST_EVENT", second, function()
            calls = calls + 1
        end)

        state.fire("TEST_EVENT")
        state.fire("TEST_EVENT")

        assert.are.equal(3, calls)
    end)

    it("isolates handler errors", function()
        local reached = false
        Events:Register("TEST_EVENT", owner, function()
            error("handler failed")
        end)
        Events:Register("TEST_EVENT", {}, function()
            reached = true
        end)

        state.fire("TEST_EVENT")

        assert.is_true(reached)
        assert.are.equal(1, #state.errors)
    end)

    describe("lifecycle", function()
        local counts

        before_each(function()
            counts = { init = 0, enable = 0 }
            local module = ns:NewModule("Probe")
            module.OnInitialize = function()
                counts.init = counts.init + 1
            end
            module.OnEnable = function()
                counts.enable = counts.enable + 1
            end
        end)

        it("ignores ADDON_LOADED for other addons", function()
            state.fire("ADDON_LOADED", "SomeOtherAddon")
            assert.are.equal(0, counts.init)
        end)

        it("initializes on its own ADDON_LOADED and enables on PLAYER_LOGIN", function()
            state.fire("ADDON_LOADED", loader.ADDON_NAME)
            assert.are.same({ init = 1, enable = 0 }, counts)

            state.fire("PLAYER_LOGIN")
            assert.are.same({ init = 1, enable = 1 }, counts)
            assert.is_false(Events:IsRegistered("PLAYER_LOGIN"))
            assert.is_false(Events:IsRegistered("ADDON_LOADED"))
        end)

        it("enables immediately when loaded after login", function()
            state.loggedIn = true
            state.fire("ADDON_LOADED", loader.ADDON_NAME)
            state.fire("PLAYER_LOGIN")
            assert.are.same({ init = 1, enable = 1 }, counts)
        end)
    end)
end)
