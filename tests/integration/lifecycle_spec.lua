local loader = require("tests.helpers.loader")

local function printedText(state)
    return table.concat(state.printed, "\n")
end

describe("addon lifecycle", function()
    local ns, state

    before_each(function()
        ns, state = loader.login()
    end)

    it("loads every TOC file and logs in without errors", function()
        assert.are.same({}, state.errors)
        assert.is_true(ns.initialized)
        assert.is_true(ns.enabled)
    end)

    it("registers the settings panel", function()
        assert.are.equal("CommonTongue", state.optionsApp)
        assert.are.equal("CommonTongue", state.blizApp)
        assert.are.equal("category-id-CommonTongue", ns.Settings.categoryID)
    end)

    describe("slash command", function()
        local function run(input)
            _G.SlashCmdList.COMMONTONGUE(input)
        end

        it("registers /ct and /commontongue", function()
            assert.are.equal("/ct", _G.SLASH_COMMONTONGUE1)
            assert.are.equal("/commontongue", _G.SLASH_COMMONTONGUE2)
        end)

        it("opens settings with no arguments", function()
            run("")
            assert.are.equal("category-id-CommonTongue", state.openedCategory)
        end)

        it("refuses to open settings in combat", function()
            state.inCombat = true
            run("")
            assert.is_nil(state.openedCategory)
            assert.truthy(printedText(state):find("in combat", 1, true))
        end)

        it("prints version and flavor", function()
            run(" Version ")
            assert.truthy(printedText(state):find("1.2.3 (Mainline)", 1, true))
        end)

        it("toggles debug mode and the debug global", function()
            run("debug")
            assert.is_true(ns.DB:Global().debug)
            assert.are.equal(ns, _G.CommonTongue)

            run("debug")
            assert.is_false(ns.DB:Global().debug)
            assert.is_nil(_G.CommonTongue)
        end)

        it("restores debug mode from saved settings", function()
            run("debug")
            local reloaded = loader.login({ savedVariables = _G.CommonTongueDB })
            assert.are.equal(reloaded, _G.CommonTongue)
        end)

        it("prints help for unknown commands", function()
            run("nonsense")
            assert.truthy(printedText(state):find("/ct version", 1, true))
        end)
    end)

    describe("settings options", function()
        local options

        before_each(function()
            options = ns.Settings.BuildOptions()
        end)

        it("toggles the addon", function()
            local enabled = options.args.enabled
            enabled.set(nil, false)
            assert.is_false(enabled.get())
            assert.is_false(ns.DB:Profile().enabled)
        end)

        it("offers auto plus every language, auto first", function()
            local target = options.args.targetLanguage
            local values = target.values()
            local sorting = target.sorting()
            assert.are.equal("auto", sorting[1])
            assert.are.equal(#ns.Languages.CODES + 1, #sorting)
            assert.truthy(values.auto:find("English", 1, true))
            assert.are.equal("Deutsch", values.deDE)

            target.set(nil, "esMX")
            assert.are.equal("esMX", ns.DB:Profile().targetLanguage)
        end)

        it("names the client language in the auto option", function()
            local deNs = loader.login({ locale = "deDE" })
            local values = deNs.Settings.BuildOptions().args.targetLanguage.values()
            assert.truthy(values.auto:find("Deutsch", 1, true))
        end)

        it("has one ordered toggle per chat type", function()
            local args = options.args.chatTypes.args
            for i, chatType in ipairs(ns.DB.CHAT_TYPES) do
                local toggle = args[chatType]
                assert.are.equal(i, toggle.order)
                assert.is_string(toggle.name)
                toggle.set(nil, false)
                assert.is_false(ns.DB:Profile().chatTypes[chatType])
                assert.is_false(toggle.get())
            end
        end)
    end)
end)
