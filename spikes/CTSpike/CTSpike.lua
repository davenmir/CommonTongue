local ADDON_NAME = ...

local PREFIX = "CTongueSpike"
local MAX_LOG = 2000
local MAX_LINES = 200

local CHAT_EVENTS = {
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
    "CHAT_MSG_EMOTE",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_GUILD",
    "CHAT_MSG_OFFICER",
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_BN_WHISPER",
    "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_CHANNEL",
    "CHAT_MSG_COMMUNITIES_CHANNEL",
    "CHAT_MSG_AFK",
    "CHAT_MSG_DND",
    "CHAT_MSG_VOICE_TEXT",
}

local CONTEXT_EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED_NEW_AREA",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "ENCOUNTER_START",
    "ENCOUNTER_END",
    "CHALLENGE_MODE_START",
    "CHALLENGE_MODE_COMPLETED",
    "CHALLENGE_MODE_RESET",
    "PVP_MATCH_ACTIVE",
    "PVP_MATCH_COMPLETE",
    "ADDON_RESTRICTION_STATE_CHANGED",
}

local SEND_RESULT = {
    [0] = "Success",
    "InvalidPrefix",
    "InvalidMessage",
    "AddonMessageThrottle",
    "InvalidChatType",
    "NotInGroup",
    "TargetRequired",
    "InvalidChannel",
    "ChannelThrottle",
    "GeneralError",
    "NotInGuild",
    "AddOnMessageLockdown",
    "TargetOffline",
}

local db
local markersEnabled = true
local lines, lineOrder = {}, {}
local filterStats = {}
local chatEventSet = {}
local lastChatState = {}
local lastLockdown
local filterApi = "none"

local function isSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) or false
end

-- Secret values cannot be tostring'd or compared from addon code.
local function show(v)
    if isSecret(v) then
        return "SECRET"
    end
    return tostring(v)
end

local function out(fmt, ...)
    print("|cff33ff99CTS|r " .. string.format(fmt, ...))
end

local function call(fn, ...)
    if not fn then
        return "n/a"
    end
    local ok, result = pcall(fn, ...)
    if not ok then
        return "error"
    end
    return result
end

local function context()
    local inInstance, instanceType = IsInInstance()
    local _, _, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
    return {
        lockdown = show(call(C_ChatInfo.InChatMessagingLockdown)),
        inInstance = show(inInstance),
        instanceType = show(instanceType),
        difficultyID = show(difficultyID),
        instanceID = show(instanceID),
        mapID = show(call(C_Map and C_Map.GetBestMapForUnit, "player")),
        encounter = show(call(C_InstanceEncounter and C_InstanceEncounter.IsEncounterInProgress)),
        challenge = show(call(C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive)),
        pvpMatch = show(call(C_PvP and C_PvP.HasMatchStarted)),
        combat = show(InCombatLockdown()),
    }
end

local function contextString(c)
    return string.format(
        "lockdown=%s instance=%s/%s diff=%s map=%s encounter=%s key=%s pvp=%s combat=%s",
        c.lockdown,
        c.inInstance,
        c.instanceType,
        c.difficultyID,
        c.mapID,
        c.encounter,
        c.challenge,
        c.pvpMatch,
        c.combat
    )
end

local function log(kind, data)
    if not db then
        return
    end
    data = data or {}
    data.kind = kind
    data.t = time()
    data.build = select(4, GetBuildInfo())
    local entries = db.log
    entries[#entries + 1] = data
    if #entries > MAX_LOG then
        table.remove(entries, 1)
    end
end

local function rememberLine(lineID, event, frameName, secret)
    local key = tostring(lineID)
    local rec = lines[key]
    if not rec then
        rec = { event = event, calls = 0, frames = {}, secret = secret }
        lines[key] = rec
        lineOrder[#lineOrder + 1] = key
        if #lineOrder > MAX_LINES then
            lines[table.remove(lineOrder, 1)] = nil
        end
    end
    rec.calls = rec.calls + 1
    rec.frames[frameName] = true

    local stat = filterStats[event]
    if not stat then
        stat = { calls = 0, frames = {} }
        filterStats[event] = stat
    end
    stat.calls = stat.calls + 1
    stat.frames[frameName] = true
end

local function chatFilter(frame, event, text, author, ...)
    local lineID = select(9, ...)
    local secret = isSecret(text)
    local ok = pcall(rememberLine, lineID, event, frame and frame:GetName() or "?", secret)
    if not ok or secret or not markersEnabled or not text then
        return false
    end
    return false, text .. " |cff888888[cts " .. tostring(lineID) .. "]|r", author, ...
end

local function onChatEvent(event, text)
    local secret = isSecret(text)
    local ctx = context()
    local stateKey = tostring(secret) .. ":" .. ctx.lockdown
    if lastChatState[event] == stateKey then
        return
    end
    lastChatState[event] = stateKey
    ctx.event = event
    ctx.textSecret = secret
    log("chat", ctx)
    out("%s textSecret=%s %s", event, tostring(secret), contextString(ctx))
end

local function onContextEvent(event, ...)
    local ctx = context()
    ctx.event = event
    if event == "ADDON_RESTRICTION_STATE_CHANGED" then
        ctx.arg1, ctx.arg2 = show((...)), show((select(2, ...)))
    end
    log("context", ctx)
    if ctx.lockdown ~= lastLockdown or event == "ADDON_RESTRICTION_STATE_CHANGED" then
        lastLockdown = ctx.lockdown
        out("%s %s", event, contextString(ctx))
    end
end

local function sendProbe()
    local me = UnitName("player")
    local probes = {
        { "PARTY" },
        { "RAID" },
        { "INSTANCE_CHAT" },
        { "GUILD" },
        { "WHISPER", me },
    }
    local ctx = context()
    for _, p in ipairs(probes) do
        local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, "ping", p[1], p[2])
        local name = ok and (SEND_RESULT[result] or tostring(result)) or "error"
        log("addonSend", { chatType = p[1], result = name, lockdown = ctx.lockdown })
        out("addon send %s -> %s", p[1], name)
    end
end

local function dataProbe()
    if C_AddOns.IsAddOnLoaded("CTSpike_Data") then
        out("data pack already loaded this session; /reload first")
        return
    end
    collectgarbage("collect")
    UpdateAddOnMemoryUsage()
    local selfBefore = GetAddOnMemoryUsage(ADDON_NAME)
    local luaBefore = collectgarbage("count")
    local t0 = debugprofilestop()
    local loaded, reason = C_AddOns.LoadAddOn("CTSpike_Data")
    local loadMs = debugprofilestop() - t0
    if not loaded then
        out("LoadAddOn failed: %s", tostring(reason))
        return
    end
    collectgarbage("collect")
    local luaDeltaKB = collectgarbage("count") - luaBefore
    UpdateAddOnMemoryUsage()
    local dataKB = GetAddOnMemoryUsage("CTSpike_Data")

    local pack = CTSpike_DataPack
    local entries, patterns = 0, 0
    local index = {}
    t0 = debugprofilestop()
    for _, chunk in ipairs(pack.chunks) do
        for _, e in ipairs(chunk) do
            entries = entries + 1
            for _, m in ipairs(e.match) do
                patterns = patterns + 1
                local first = m:match("^(%S+)")
                local bucket = index[first]
                if not bucket then
                    bucket = {}
                    index[first] = bucket
                end
                bucket[#bucket + 1] = e.id
            end
        end
    end
    local indexMs = debugprofilestop() - t0
    UpdateAddOnMemoryUsage()
    local indexKB = GetAddOnMemoryUsage(ADDON_NAME) - selfBefore

    local result = {
        fileBytes = pack.bytes,
        entries = entries,
        patterns = patterns,
        loadMs = loadMs,
        dataKB = dataKB,
        luaDeltaKB = luaDeltaKB,
        indexMs = indexMs,
        indexKB = indexKB,
    }
    log("data", result)
    out(
        "data: %d bytes on disk, %d entries, %d patterns | load %.1f ms, %.0f KB (heap +%.0f KB) | index %.1f ms, %.0f KB",
        pack.bytes,
        entries,
        patterns,
        loadMs,
        dataKB,
        luaDeltaKB,
        indexMs,
        indexKB
    )
end

local function printLines()
    local from = math.max(1, #lineOrder - 9)
    for i = from, #lineOrder do
        local key = lineOrder[i]
        local rec = lines[key]
        local frames = {}
        for name in pairs(rec.frames) do
            frames[#frames + 1] = name
        end
        out("line %s %s calls=%d frames=%s secret=%s", key, rec.event, rec.calls, table.concat(frames, ","), tostring(rec.secret))
    end
    log("lines", { count = #lineOrder })
end

local function frameList(set)
    local names = {}
    for name in pairs(set) do
        names[#names + 1] = name
    end
    table.sort(names)
    return table.concat(names, ",")
end

local function printEvents()
    local registered, seen = 0, 0
    local summary = {}
    for _, event in ipairs(CHAT_EVENTS) do
        if chatEventSet[event] then
            registered = registered + 1
        end
        local stat = filterStats[event]
        if stat then
            seen = seen + 1
            summary[event] = { calls = stat.calls, frames = frameList(stat.frames) }
            out("%s calls=%d frames=%s", event, stat.calls, summary[event].frames)
        end
    end
    out("filter registered on %d events; %d have fired so far", registered, seen)
    log("events", { registered = registered, seen = seen, stats = summary })
end

local commands = {
    status = function()
        out("filter api: %s, markers: %s, log entries: %d", filterApi, tostring(markersEnabled), #db.log)
        out(contextString(context()))
    end,
    markers = function()
        markersEnabled = not markersEnabled
        out("markers %s", markersEnabled and "on" or "off")
    end,
    lines = printLines,
    events = printEvents,
    addon = sendProbe,
    data = dataProbe,
    reset = function()
        wipe(db.log)
        out("log cleared")
    end,
}

local function help()
    out("/cts status | markers | lines | events | addon | data | reset")
end

local frame = CreateFrame("Frame")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON_NAME then
            return
        end
        CTSpikeDB = CTSpikeDB or {}
        db = CTSpikeDB
        db.log = db.log or {}
        log("loaded", { filterApi = filterApi })
        out("loaded (filter api: %s). /cts for commands.", filterApi)
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender = ...
        if not isSecret(prefix) and prefix == PREFIX then
            log("addonRecv", { channel = show(channel), textSecret = isSecret(text), senderSecret = isSecret(sender) })
            out("addon recv on %s (textSecret=%s)", show(channel), tostring(isSecret(text)))
        end
    elseif chatEventSet[event] then
        onChatEvent(event, (...))
    else
        onContextEvent(event, ...)
    end
end)

local addFilter
if ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter then
    addFilter, filterApi = ChatFrameUtil.AddMessageEventFilter, "ChatFrameUtil.AddMessageEventFilter"
elseif ChatFrame_AddMessageEventFilter then
    addFilter, filterApi = ChatFrame_AddMessageEventFilter, "ChatFrame_AddMessageEventFilter"
end

for _, event in ipairs(CHAT_EVENTS) do
    if addFilter then
        addFilter(event, chatFilter)
    end
    if pcall(frame.RegisterEvent, frame, event) then
        chatEventSet[event] = true
    end
end
for _, event in ipairs(CONTEXT_EVENTS) do
    pcall(frame.RegisterEvent, frame, event)
end
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("CHAT_MSG_ADDON")
C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

SLASH_CTSPIKE1 = "/cts"
SlashCmdList.CTSPIKE = function(msg)
    local cmd = commands[strtrim(msg or ""):lower()]
    if cmd then
        cmd()
    else
        help()
    end
end
