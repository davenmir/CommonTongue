# CommonTongue — Architecture

Status: draft, pending M0 findings. Sections that depend on unverified platform
facts are marked `> UNVERIFIED:`.

## 1. Platform constraints

| Constraint | Consequence |
|---|---|
| Lua 5.1 sandbox; no `io`, `os.execute`, sockets, `require` | All logic and data ship inside the addon; modules share a namespace table instead of `require` |
| No network | Offline translation only (ADR-0001, ADR-0002) |
| SavedVariables read at login, written at logout/`/reload` | Settings and learned data persist, but cannot be used as a live IPC channel |
| Scripts exceeding the per-frame time budget are killed | Heavy work must be bounded per message and spread across frames if needed |
| Secure frames / taint | Chat must be modified only through sanctioned filters and hooks |
| No `utf8` library; strings are byte arrays | We implement our own UTF-8 helpers (`Core/UTF8.lua`); WoW provides `strlenutf8` |
| Addon messages limited in size and rate | Protocol must be compact and use a throttled send queue |

### 1.1 Retail chat messaging lockdown (12.x)

Documented (warcraft.wiki.gg "Secret Values", "CHAT_MSG_PARTY",
"C_ChatInfo.SendAddonMessage", retrieved 2026-10-11):

- `CHAT_MSG_*` events carry the `SecretInChatMessagingLockdown` predicate. While
  lockdown is active, `text`, `playerName`, `guid` and `playerName2` arrive as
  secret values. `lineID`, `channelName`, `zoneChannelID`, `languageID` and
  `specialFlags` are `NeverSecret`.
- Tainted code (all addon code, including chat filters) may store, pass and
  concatenate secret strings but may not compare, index, measure (`#`), use as
  table keys, or run `string.find`/`gsub` on them. Violations are immediate Lua
  errors.
- Detection: `issecretvalue(v)` per value; `C_ChatInfo.InChatMessagingLockdown()`
  for the global state (its `lockdownReason` return was removed in 12.0.5).
- During lockdown, addons cannot send addon messages
  (`Enum.SendAddonMessageResult.AddOnMessageLockdown`) or regular chat.
- Consequence: `UI/ChatFilter.lua` must check `issecretvalue(text)` before any
  string operation and pass the line through untouched. Tiers 1–3 are all
  unavailable for that line; the composer must disable sending.

> UNVERIFIED: when lockdown applies. Blizzard's Oct 2025 alpha notes say only
> while a keystone run, PvP match, or instance encounter is in progress. The
> current wiki predicate text adds "when the player is on a
> communication-restricted map such as a dungeon or raid". If the latter holds,
> CommonTongue cannot read party/raid chat anywhere inside dungeons and raids.
> Needs in-game check (see `tests/ingame/CHECKLIST.md`).

## 2. High-level data flow

```
Incoming chat event (CHAT_MSG_*)
        │
        ▼
 Chat filter (UI/ChatFilter.lua) ── secret/blocked? ──► pass through untouched
        │
        ▼
 Protocol cache lookup (Comm/) ── match from same sender? ──► Tier 1 render
        │ no
        ▼
 Normalizer (Engine/Normalize.lua): strip colors, tokenize links → placeholders
        │
        ▼
 Language detector (Engine/Detect.lua) ── same as target? ──► pass through
        │
        ▼
 Phrase engine (Engine/Phrase.lua) ── match ──► Tier 2 render
        │ no match
        ▼
 Gloss (Engine/Gloss.lua) ──► language tag + hover gloss (Tier 3)
        │
        ▼
 Renderer (UI/Render.lua): rebuild line, restore links, apply markers
```

Coverage: the filter is registered on every player-authored chat event (SAY,
YELL, EMOTE, PARTY/RAID/INSTANCE incl. leader variants, RAID_WARNING, GUILD,
OFFICER, WHISPER/BN_WHISPER incl. `_INFORM`, CHANNEL, COMMUNITIES_CHANNEL,
AFK/DND auto-replies, VOICE_TEXT), defined in one list in `UI/ChatFilter.lua`.
Message event filters apply to every chat frame showing the event — all tabs,
user-created windows, and pop-out whisper windows — so no per-window hooking is
needed. Users can disable translation per chat type in settings.

> UNVERIFIED: chat replacement addons (e.g. EllesmereUIChat, Chattynator,
> Glass, Prat) honor message event filters. Check before claiming
> compatibility. EllesmereUIChat is in the developer's own test setup and is
> confirmed to render chat text its own way: it leaves `|4singular:plural;`
> grammar escapes unprocessed (seen in `/played`, build 120100), so it may also
> bypass or alter filter output.

Outgoing:

```
Composer (UI/Composer.lua) → phrase ID + params
   ├─► C_ChatInfo.SendChatMessage(rendered text in sender's chosen outgoing language)
   └─► Comm/Protocol.lua → throttled addon message with phrase ID + params
```

Sending must happen inside a click handler: SAY, YELL and CHANNEL require a
hardware event. Both sends are blocked during chat messaging lockdown (§1.1).

## 3. Modules

Each file registers into the shared namespace: `local _, ns = ...`.

| Module | File(s) | Responsibility |
|---|---|---|
| Bootstrap | `Core/Init.lua` | Create `ns`, version info, module registry, load order |
| Compat | `Core/Compat.lua`, `Core/Compat_<Flavor>.lua` | Single access point for flavor-divergent APIs (ADR-0003) |
| Events | `Core/Events.lua` | Event dispatcher; modules subscribe instead of owning frames |
| DB | `Core/DB.lua` | SavedVariables defaults, versioned migrations |
| UTF8 | `Core/UTF8.lua` | Codepoint iteration, length, safe truncation, script classification |
| Locale | `Locales/*.lua` | UI strings (`L` table), *not* translation data |
| Normalize | `Engine/Normalize.lua` | Text → token stream with placeholders for links, icons, numbers |
| Detect | `Engine/Detect.lua` | Language ID + confidence |
| Phrase | `Engine/Phrase.lua` | Pattern matching to phrase IDs and rendering |
| Gloss | `Engine/Gloss.lua` | Word lookup for approximate hints |
| DataLoader | `Engine/Data.lua` | Registers language packs, lazy-builds indexes |
| Protocol | `Comm/Protocol.lua` | Wire format encode/decode, versioning |
| Transport | `Comm/Transport.lua` | Thin wrapper over AceComm (ADR-0004): prefix registration, send/receive, lockdown check; chunking and throttling are AceComm/ChatThrottleLib's job |
| Correlate | `Comm/Correlate.lua` | Matches addon messages to visible chat lines |
| ChatFilter | `UI/ChatFilter.lua` | Hooks chat events, drives the pipeline |
| Render | `UI/Render.lua` | Output formatting, tier markers, hover tooltips |
| Composer | `UI/Composer.lua` | Quick-phrase picker / autocomplete |
| Settings | `UI/Settings.lua` | Options panel |

Dependency rule: `UI → Comm → Engine → Core`. Lower layers never reference
higher ones. `Engine/` must be pure logic with no WoW API calls (other than via
`Core/`), so it can be unit tested outside the client.

`Locales/` and `Data/` are passive registration files, not layers. `Locales/`
loads right after `Core/`. `Data/` calls `ns.Data.Register*` and therefore loads
after `Engine/Data.lua`. TOC order: `Libs/` → `Core/` → `Locales/` → `Engine/` →
`Data/` → `Comm/` → `UI/`.

## 4. Phrase model

A **phrase** is a language-neutral meaning with typed parameters:

```lua
-- Data/Phrases.lua (language-neutral catalog)
ns.Data.RegisterPhrases({
    LFM_ROLES = { params = { activity = "activity", roles = "roleList" } },
    WTS_ITEM_PRICE = { params = { item = "link", price = "gold" } },
    THANKS = {},
})
```

Each language pack provides **match patterns** (input side) and **render
templates** (output side) for phrase IDs:

```lua
-- Data/deDE/Phrases.lua
ns.Data.RegisterLanguage("deDE", {
    reviewed = false, -- set true only after native-speaker review
    phrases = {
        THANKS = {
            match = { "danke", "dankeschön", "thx", "ty" },
            render = "Danke",
        },
        LFM_ROLES = {
            match = { "suche {roles} für {activity}", "lfm {roles} {activity}" },
            render = "Suche {roles} für {activity}",
        },
    },
})
```

Parameter types (`roleList`, `gold`, `number`, `link`, `activity`, ...) have
per-language parsers and formatters in `Engine/Params.lua`. Item/spell/quest
links are never translated; the client renders them in the reader's locale.

Data packs are loaded at startup but indexes (e.g. first-token lookup tables)
are built lazily on first use per language to keep login time low.

## 5. Language data governance

- Every language pack has `reviewed = true|false`. Agent-drafted data is
  `false`. UI may show unreviewed translations with a subtle marker.
- `tools/validate_data.lua` checks: every `match` has a `render`, all
  placeholders in templates exist in the phrase's `params`, no duplicate
  patterns, valid UTF-8.

## 6. CommonTongue protocol (Tier 1)

Detailed wire format requires an ADR in M4. Design intent:

- Prefix: `CTongue` (≤ 16 chars).
- Message: `<version>|<phraseId>|<k=v;k=v>|<corr>` where `corr` is a short hash
  of the visible chat text, used by `Comm/Correlate.lua` to attach the payload
  to the matching chat line from the same sender within a short time window.
- Unknown versions or phrase IDs fall back silently to Tier 2/3.
- Channels: group, raid, instance, guild, whisper.

Documented limits (warcraft.wiki.gg "C_ChatInfo.SendAddonMessage", retrieved
2026-10-11):

- Prefix ≤ 16 characters, registered with `C_ChatInfo.RegisterAddonMessagePrefix`.
- Payload ≤ 255 characters; any byte except NUL.
- Throttle per prefix: burst of 10 messages, regaining 1 per second; whispers
  outside instances are exempt. The server may change these numbers at any time.
- Retail chat types: PARTY, RAID, INSTANCE_CHAT, GUILD, OFFICER, WHISPER,
  CHANNEL (custom channels only). SAY and YELL are Classic-only.
- Returns `Enum.SendAddonMessageResult` (12.0 added `AddOnMessageLockdown`
  and `TargetOffline`).
- Blocked entirely during chat messaging lockdown (§1.1).

Public zone channels (Trade, General) cannot carry addon messages, so they rely
on Tier 2. AceComm (ADR-0004) splits long payloads across messages, so the
per-message limit constrains throughput rather than message size.

## 7. Multi-flavor strategy

See ADR-0003. Summary: one codebase, one TOC per flavor
(`CommonTongue_Mainline.toc`, `CommonTongue_Vanilla.toc`,
`CommonTongue_Mists.toc`, ...). Flavor detection lives in `Core/Compat.lua`
(via `WOW_PROJECT_ID`); flavor-specific implementations live in
`Core/Compat_<Flavor>.lua`, listed only in that flavor's TOC. Phrase data that
differs per flavor (dungeon names, roles) is tagged with a `flavors` field.

## 8. Performance budget

- Chat filter median < 0.1 ms per message; worst case < 1 ms.
- Fast exits first: disabled channel → own messages → same language as target.
- Cache results per chat line for the duration of a line's display (chat
  filters run once per chat frame, so the same message is filtered multiple
  times). Key by the event's line ID rather than (sender, message), since the
  same text can legitimately be sent twice. `lineID` is event argument 11,
  documented as unique per line and `NeverSecret`, so it is usable as a key
  even during lockdown.
- No per-message table allocation in hot paths where avoidable.

## 9. Open questions (resolve in M0)

1. Secret values for chat events — documented (§1.1). Open: whether lockdown
   covers the whole dungeon/raid map or only active keys/encounters/PvP
   matches. In-game check pending.
2. Addon message limits and chat types — documented (§6).
3. Chat filter API — on Retail 12.0+ it is `ChatFrameUtil.AddMessageEventFilter`
   (same signature); `ChatFrame_AddMessageEventFilter` survives only as an alias
   in `Blizzard_DeprecatedChatInfo`. `Core/Compat.lua` picks
   `ChatFrameUtil.AddMessageEventFilter` when present, else the legacy global
   (source: wow-ui-source 12.0.0 `Deprecated_ChatFrame.lua`). Confirmed present
   in-game on build 120100 (2026-10-11); open-world SAY/WHISPER/CHANNEL text is
   readable outside lockdown. Rewriting across all target events and group
   chat types still pending.
4. Memory/load cost of the data packs — measured on build 120100 (2026-10-11):
   a 1.1 MB synthetic pack (6,000 phrases, 18,000 patterns) took 545 ms to
   load and ~4.6 MB of memory (≈4× file size); building a first-token index
   took 6 ms and 650 KB. Consequences for M3: load only the languages the user
   needs (target + enabled source languages), never all packs; load at login or
   out of combat, never mid-fight, since a half-second load freezes the client;
   keep per-language packs well under 1 MB. Whether packs become separate
   load-on-demand addons is an M3 ADR.
5. Library choice — decided, ADR-0004 accepted.
