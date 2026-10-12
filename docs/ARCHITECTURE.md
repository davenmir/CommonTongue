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

> UNVERIFIED: Retail (12.x) "secret values" may make chat message contents
> unreadable by addons in some contexts (e.g. during encounters or in restricted
> instances). If so, the engine must detect secret values and skip gracefully.
> M0 task.

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

Outgoing:

```
Composer (UI/Composer.lua) → phrase ID + params
   ├─► SendChatMessage(rendered text in sender's chosen outgoing language)
   └─► Comm/Protocol.lua → throttled addon message with phrase ID + params
```

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
| Transport | `Comm/Transport.lua` | Prefix registration, send/receive; delegates chunking and throttling to AceComm/ChatThrottleLib if ADR-0004 is accepted, otherwise owns them |
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

> UNVERIFIED: addon message payload limit (believed 255 bytes), throttle rules,
> and whether SAY/YELL/public channels can carry addon messages on Retail.
> Public channels (Trade, General) likely cannot be covered by Tier 1 and rely
> on Tier 2. M0 task. If AceComm is adopted (ADR-0004), it splits long
> payloads across messages, so the per-message limit constrains throughput
> rather than message size.

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
  same text can legitimately be sent twice.

> UNVERIFIED: the line ID argument (believed to be the 11th event argument of
> `CHAT_MSG_*`) is unique per line and identical across chat frames. M0 task.
- No per-message table allocation in hot paths where avoidable.

## 9. Open questions (resolve in M0)

1. Exact Retail behavior of secret values for chat events.
2. Addon message limits and permitted chat types on Retail.
3. Whether `ChatFrame_AddMessageEventFilter` is still the sanctioned API on the
   current Retail build, or has moved (e.g. into a `ChatFrameUtil` namespace).
4. Memory/load cost of the data packs at target size.
5. Library choice (ADR-0004).
