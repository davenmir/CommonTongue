local loader = require("tests.helpers.loader")
local stubs = loader.stubs

local CORE = { "Core/Init.lua", "Core/Compat.lua" }

describe("Compat", function()
    describe("flavor detection", function()
        local cases = {
            WOW_PROJECT_MAINLINE = "Mainline",
            WOW_PROJECT_CLASSIC = "Vanilla",
            WOW_PROJECT_BURNING_CRUSADE_CLASSIC = "TBC",
            WOW_PROJECT_WRATH_CLASSIC = "Wrath",
            WOW_PROJECT_CATACLYSM_CLASSIC = "Cata",
            WOW_PROJECT_MISTS_CLASSIC = "Mists",
        }
        for project, flavor in pairs(cases) do
            it("maps " .. project .. " to " .. flavor, function()
                local ns = loader.load({ files = CORE, flavor = project })
                assert.are.equal(flavor, ns.Compat.flavor)
                assert.are.equal(flavor == "Mainline", ns.Compat.isRetail)
            end)
        end

        it("reports Unknown for an unrecognized project", function()
            stubs.install()
            _G.WOW_PROJECT_ID = 999
            local ns = {}
            for _, file in ipairs(CORE) do
                loadfile(loader.ADDON_DIR .. file)(loader.ADDON_NAME, ns)
            end
            assert.are.equal("Unknown", ns.Compat.flavor)
        end)
    end)

    describe("on Retail", function()
        local ns, state, Compat

        before_each(function()
            ns, state = loader.load({
                files = { "Core/Init.lua", "Core/Compat.lua", "Core/Compat_Mainline.lua" },
            })
            Compat = ns.Compat
        end)

        it("exposes the restriction change event", function()
            assert.are.equal("ADDON_RESTRICTION_STATE_CHANGED", Compat.restrictionEvent)
        end)

        it("detects secret values", function()
            local secret = stubs.secret("text")
            state.secrets[secret] = true
            assert.is_true(Compat.IsSecret(secret))
            assert.is_false(Compat.IsSecret("plain"))
        end)

        it("reports chat lockdown", function()
            assert.is_false(Compat.InChatLockdown())
            state.lockdown = true
            assert.is_true(Compat.InChatLockdown())
        end)

        it("registers chat filters through ChatFrameUtil", function()
            local fn = function() end
            Compat.AddMessageEventFilter("CHAT_MSG_SAY", fn)
            assert.are.equal(fn, state.filters.CHAT_MSG_SAY)
            Compat.RemoveMessageEventFilter("CHAT_MSG_SAY", fn)
            assert.is_nil(state.filters.CHAT_MSG_SAY)
        end)

        it("opens settings out of combat only", function()
            assert.is_true(Compat.OpenSettings("cat"))
            assert.are.equal("cat", state.openedCategory)

            state.openedCategory = nil
            state.inCombat = true
            assert.is_false(Compat.OpenSettings("cat"))
            assert.is_nil(state.openedCategory)
        end)

        it("reads addon metadata", function()
            assert.are.equal("1.2.3", Compat.GetAddOnMetadata("CommonTongue", "Version"))
        end)
    end)

    describe("on clients without newer APIs", function()
        local ns, Compat

        before_each(function()
            ns = loader.load({ files = CORE, flavor = "WOW_PROJECT_CLASSIC" })
            Compat = ns.Compat
            _G.issecretvalue = nil
            _G.C_ChatInfo = {}
            _G.C_AddOns = nil
            _G.GetAddOnMetadata = function()
                return "legacy"
            end
            _G.ChatFrameUtil = nil
        end)

        it("treats nothing as secret and never reports lockdown", function()
            assert.is_false(Compat.IsSecret("text"))
            assert.is_false(Compat.InChatLockdown())
            assert.is_nil(Compat.restrictionEvent)
        end)

        it("falls back to legacy globals", function()
            local registered
            _G.ChatFrame_AddMessageEventFilter = function(event)
                registered = event
            end
            Compat.AddMessageEventFilter("CHAT_MSG_SAY", function() end)
            assert.are.equal("CHAT_MSG_SAY", registered)
            assert.are.equal("legacy", Compat.GetAddOnMetadata("CommonTongue", "Version"))
        end)

        it("reports errors through the error handler when securecallfunction is missing", function()
            local caught
            _G.securecallfunction = nil
            _G.geterrorhandler = function()
                return function(err)
                    caught = err
                end
            end
            Compat.SafeCall(function()
                error("oops")
            end)
            assert.truthy(tostring(caught):find("oops"))
        end)
    end)
end)
