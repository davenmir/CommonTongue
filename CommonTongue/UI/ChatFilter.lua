local _, ns = ...
local ChatFilter = ns:NewModule("ChatFilter")

local MAX_CACHE = 256
local MIN_DETECT = 0.4
local MIN_TAG = 0.55

local EVENT_TYPE = {
    CHAT_MSG_SAY = "SAY",
    CHAT_MSG_YELL = "YELL",
    CHAT_MSG_EMOTE = "EMOTE",
    CHAT_MSG_PARTY = "PARTY",
    CHAT_MSG_PARTY_LEADER = "PARTY",
    CHAT_MSG_RAID = "RAID",
    CHAT_MSG_RAID_LEADER = "RAID",
    CHAT_MSG_RAID_WARNING = "RAID",
    CHAT_MSG_INSTANCE_CHAT = "INSTANCE",
    CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE",
    CHAT_MSG_GUILD = "GUILD",
    CHAT_MSG_OFFICER = "OFFICER",
    CHAT_MSG_WHISPER = "WHISPER",
    CHAT_MSG_WHISPER_INFORM = "WHISPER",
    CHAT_MSG_BN_WHISPER = "BN_WHISPER",
    CHAT_MSG_BN_WHISPER_INFORM = "BN_WHISPER",
    CHAT_MSG_CHANNEL = "CHANNEL",
    CHAT_MSG_COMMUNITIES_CHANNEL = "COMMUNITIES",
    CHAT_MSG_VOICE_TEXT = "SAY",
}

local cache = {}
local cacheOrder = {}
local loggedErrors = {}

local function cacheGet(lineID)
    return cache[lineID]
end

local function cacheSet(lineID, value)
    if lineID == nil then
        return
    end
    if cache[lineID] == nil then
        cacheOrder[#cacheOrder + 1] = lineID
        if #cacheOrder > MAX_CACHE then
            cache[table.remove(cacheOrder, 1)] = nil
        end
    end
    cache[lineID] = value
end

local function targetLanguage()
    return ns.Languages.Resolve(ns.DB:Profile().targetLanguage, ns.Compat.GetClientLocale())
end

--- Pure pipeline used by the filter and by tests. Never throws.
---@return string|nil rewritten text, or nil to leave the line alone
function ChatFilter.Process(text, author, event)
    local profile = ns.DB:Profile()
    if not profile.enabled then
        return nil
    end
    local chatType = EVENT_TYPE[event]
    if not chatType or not profile.chatTypes[chatType] then
        return nil
    end
    if ns.Compat.IsSecret(text) or ns.Compat.IsSecret(author) then
        return nil
    end
    if type(text) ~= "string" or text == "" then
        return nil
    end
    if ns.Compat.IsSelf(author) and not profile.translateSelf then
        return nil
    end

    local target = targetLanguage()
    if profile.protocol ~= false and ns.Correlate then
        local proto = ns.Correlate.Take(author, text)
        if proto and proto.kind == ns.Protocol.KIND_PHRASE then
            local rendered, reviewed = ns.Phrase.Render(proto.id, proto.params, target)
            if rendered then
                local norm = ns.Normalize.Run(text)
                rendered = ns.Normalize.Restore(rendered, norm.placeholders)
                if rendered ~= text then
                    return ns.Render.Protocol(rendered, text, target, reviewed)
                end
            end
        end
    end

    local norm = ns.Normalize.Run(text)
    local lang, confidence = ns.Detect.Identify(norm.normalized, norm.tokens)
    if lang and lang == target and confidence >= MIN_DETECT then
        return nil
    end

    local hit = ns.Phrase.Match(norm.tokens, lang)
    if hit then
        local rendered, targetReviewed = ns.Phrase.Render(hit.id, hit.params, target)
        if rendered then
            rendered = ns.Normalize.Restore(rendered, norm.placeholders)
            local source = ns.Data.GetLanguage(hit.language)
            local reviewed = targetReviewed and source and source.reviewed
            return ns.Render.Phrase(rendered, text, hit.language, target, reviewed)
        end
    end

    if lang and lang ~= target and confidence >= MIN_TAG then
        return ns.Render.LanguageTag(text, lang)
    end
    return nil
end

-- frame is required by the chat-filter API; we cache by lineID instead.
local function filter(_, event, text, author, ...)
    local lineID = select(9, ...)
    local cached = cacheGet(lineID)
    if cached ~= nil then
        if cached == false then
            return false
        end
        return false, cached, author, ...
    end

    local ok, rewritten = pcall(ChatFilter.Process, text, author, event)
    if not ok then
        local sig = tostring(rewritten)
        if ns.DB:Global().debug and not loggedErrors[sig] then
            loggedErrors[sig] = true
            ns:Print(sig)
        end
        cacheSet(lineID, false)
        return false
    end
    if rewritten then
        cacheSet(lineID, rewritten)
        return false, rewritten, author, ...
    end
    cacheSet(lineID, false)
    return false
end

function ChatFilter:OnEnable()
    for event in pairs(EVENT_TYPE) do
        ns.Compat.AddMessageEventFilter(event, filter)
    end
end

ChatFilter.EVENT_TYPE = EVENT_TYPE
