local loader = require("tests.helpers.loader")

describe("DB", function()
    describe("Migrate", function()
        local DB

        before_each(function()
            local ns = loader.load()
            DB = ns.DB
        end)

        it("stamps fresh data with the current schema", function()
            local sv = {}
            assert.is_true(DB.Migrate(sv))
            assert.are.equal(DB.SCHEMA_VERSION, sv.global.schemaVersion)
        end)

        it("runs each pending migration once, in order", function()
            local ran = {}
            DB.SCHEMA_VERSION = 3
            DB.migrations[2] = function(sv)
                ran[#ran + 1] = 2
                sv.profiles = { Default = { renamed = sv.global.old } }
            end
            DB.migrations[3] = function()
                ran[#ran + 1] = 3
            end
            local sv = { global = { schemaVersion = 1, old = "value" } }

            DB.Migrate(sv)
            DB.Migrate(sv)

            assert.are.same({ 2, 3 }, ran)
            assert.are.equal("value", sv.profiles.Default.renamed)
            assert.are.equal(3, sv.global.schemaVersion)
        end)

        it("leaves data from a newer version untouched", function()
            local sv = { global = { schemaVersion = DB.SCHEMA_VERSION + 1 } }
            assert.is_false(DB.Migrate(sv))
            assert.are.equal(DB.SCHEMA_VERSION + 1, sv.global.schemaVersion)
        end)
    end)

    describe("after login", function()
        it("creates SavedVariables with defaults", function()
            local ns = loader.login()
            local profile = ns.DB:Profile()

            assert.is_table(_G.CommonTongueDB)
            assert.is_true(profile.enabled)
            assert.are.equal("auto", profile.targetLanguage)
            for _, chatType in ipairs(ns.DB.CHAT_TYPES) do
                assert.is_true(profile.chatTypes[chatType], chatType)
            end
            assert.is_false(ns.DB:Global().debug)
        end)

        it("keeps saved settings across sessions", function()
            local ns = loader.login()
            ns.DB:Profile().targetLanguage = "deDE"
            ns.DB:Profile().chatTypes.CHANNEL = false
            local saved = _G.CommonTongueDB

            local reloaded = loader.login({ savedVariables = saved })

            assert.are.equal("deDE", reloaded.DB:Profile().targetLanguage)
            assert.is_false(reloaded.DB:Profile().chatTypes.CHANNEL)
            assert.is_true(reloaded.DB:Profile().chatTypes.SAY)
        end)

        it("warns when saved data is from a newer version", function()
            local _, state = loader.login({ savedVariables = { global = { schemaVersion = 99 } } })
            assert.truthy(table.concat(state.printed, "\n"):find("newer version", 1, true))
        end)
    end)
end)
