local loader = require("tests.helpers.loader")

local DE_LFG = "Suche Tank und Heiler für +10"

describe("ChatFilter", function()
    local ns, state

    before_each(function()
        ns, state = loader.login({ locale = "enUS" })
        ns.DB:Profile().targetLanguage = "enUS"
        ns.DB:Profile().translateSelf = true
    end)

    it("rewrites the Spanish LFG line into English", function()
        local out = ns.ChatFilter.Process("LFM Tank y healer para +10", "Other", "CHAT_MSG_SAY")
        assert.truthy(out)
        assert.truthy(out:find("LFM tank and healer for +10", 1, true))
        assert.truthy(out:find("[es→en]", 1, true))
        assert.truthy(out:find("(unreviewed)", 1, true))
    end)

    it("rewrites German LFG into English", function()
        local out = ns.ChatFilter.Process(DE_LFG, "Other", "CHAT_MSG_SAY")
        assert.truthy(out:find("LFM tank and healer for +10", 1, true))
        assert.truthy(out:find("[de→en]", 1, true))
    end)

    it("leaves same-language chat alone", function()
        local line = "looking for tank and healer for the key"
        assert.is_nil(ns.ChatFilter.Process(line, "Other", "CHAT_MSG_SAY"))
    end)

    it("skips the player's own messages unless translateSelf is on", function()
        ns.DB:Profile().translateSelf = false
        assert.is_nil(ns.ChatFilter.Process(DE_LFG, "Tester", "CHAT_MSG_SAY"))
        ns.DB:Profile().translateSelf = true
        assert.truthy(ns.ChatFilter.Process(DE_LFG, "Tester", "CHAT_MSG_SAY"))
    end)

    it("passes secret text through without reading it", function()
        local secret = loader.stubs.secret("chat")
        state.secrets[secret] = true
        assert.is_nil(ns.ChatFilter.Process(secret, "Other", "CHAT_MSG_SAY"))
    end)

    it("respects per-chat-type toggles and the master switch", function()
        ns.DB:Profile().chatTypes.SAY = false
        assert.is_nil(ns.ChatFilter.Process(DE_LFG, "Other", "CHAT_MSG_SAY"))
        ns.DB:Profile().chatTypes.SAY = true
        ns.DB:Profile().enabled = false
        assert.is_nil(ns.ChatFilter.Process(DE_LFG, "Other", "CHAT_MSG_SAY"))
    end)

    it("tags high-confidence uncovered foreign text without claiming a translation", function()
        local line = "was für ein schöner Sonnenuntergang heute"
        local out = ns.ChatFilter.Process(line, "Other", "CHAT_MSG_SAY")
        assert.truthy(out)
        assert.truthy(out:find(line, 1, true))
        assert.truthy(out:find("[de]", 1, true))
        assert.is_nil(out:find("→", 1, true))
    end)

    it("registers a filter that rewrites and caches by lineID", function()
        local fn = state.filters.CHAT_MSG_SAY
        assert.is_function(fn)
        local extra = { "lang", "chan", "p2", "flags", 0, 0, "chan", 0, 42 }
        local discard, text = fn({
            GetName = function()
                return "ChatFrame1"
            end,
        }, "CHAT_MSG_SAY", DE_LFG, "Other", unpack(extra))
        assert.is_false(discard)
        assert.truthy(text:find("LFM tank and healer for +10", 1, true))
        -- second frame, same lineID, same rewrite
        local _, again = fn({}, "CHAT_MSG_SAY", DE_LFG, "Other", unpack(extra))
        assert.are.equal(text, again)
    end)
end)
