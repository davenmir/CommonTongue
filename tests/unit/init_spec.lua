local loader = require("tests.helpers.loader")

local CORE = { "Core/Init.lua", "Core/Compat.lua" }

describe("Init", function()
    local ns, state

    before_each(function()
        ns, state = loader.load({ files = CORE })
    end)

    it("registers modules on the namespace in load order", function()
        local a = ns:NewModule("Alpha")
        local b = ns:NewModule("Beta")
        assert.are.equal(a, ns.Alpha)
        assert.are.equal("Beta", b.name)
        assert.are.equal(a, ns.moduleOrder[#ns.moduleOrder - 1])
        assert.are.equal(b, ns.moduleOrder[#ns.moduleOrder])
    end)

    it("rejects duplicate modules and names that collide with namespace fields", function()
        ns:NewModule("Alpha")
        assert.has_error(function()
            ns:NewModule("Alpha")
        end)
        assert.has_error(function()
            ns:NewModule("L")
        end)
    end)

    it("runs OnInitialize then OnEnable once each, in module order", function()
        local calls = {}
        for _, name in ipairs({ "One", "Two" }) do
            local module = ns:NewModule(name)
            module.OnInitialize = function(self)
                calls[#calls + 1] = "init:" .. self.name
            end
            module.OnEnable = function(self)
                calls[#calls + 1] = "enable:" .. self.name
            end
        end

        ns:Initialize()
        ns:Initialize()
        ns:Enable()
        ns:Enable()

        assert.are.same({ "init:One", "init:Two", "enable:One", "enable:Two" }, calls)
    end)

    it("keeps initializing other modules when one errors", function()
        local reached = false
        ns:NewModule("Broken").OnInitialize = function()
            error("boom")
        end
        ns:NewModule("Fine").OnInitialize = function()
            reached = true
        end

        ns:Initialize()

        assert.is_true(reached)
        assert.are.equal(1, #state.errors)
        assert.truthy(tostring(state.errors[1]):find("boom"))
    end)

    it("falls back to the key for missing locale strings", function()
        assert.are.equal("Not translated", ns.L["Not translated"])
    end)

    it("prints with the addon prefix", function()
        ns:Print("hello")
        assert.truthy(state.printed[1]:find("CommonTongue", 1, true))
        assert.truthy(state.printed[1]:find("hello", 1, true))
    end)
end)
