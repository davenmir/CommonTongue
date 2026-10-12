# ADR-0006: CommonTongue protocol wire format v1

- Status: Accepted
- Date: 2026-10-12
- Deciders: agent (user asked to continue into M4 after merging M3)

## Context

Tier 1 (ADR-0002) sends language-neutral phrase IDs over addon messages so
another CommonTongue user can render the line in their target language. Retail
limits the prefix to 16 characters and the payload to 255 bytes per frame
(AceComm chunks longer payloads). Addon messages are available on PARTY, RAID,
INSTANCE_CHAT, GUILD, OFFICER, WHISPER, and custom CHANNEL — not SAY, YELL, or
public channels such as Trade. Chat filters run synchronously, so a payload
that arrives after the visible line cannot rewrite it.

## Decision

- Prefix: `CTongue`.
- Version field is a decimal integer. v1 messages are `|`-separated fields.
  Param values percent-encode `%`, `|`, `;`, `=`, and spaces. Unknown versions
  and unknown phrase IDs are ignored; the chat filter falls through to Tier 2.
- Phrase: `1|P|<phraseId>|<k=v;k=v>|<corr>`
  - `corr` is an 8-character lowercase djb2-32 hex digest of the exact visible
    chat string. `Comm/Correlate.lua` matches `(short sender name, corr)`
    within a 3-second window.
  - Typed params use canonical forms: roles `tank,healer,dps`; gold `50g5s`;
    numbers `10` or `+10`; links and activity as percent-encoded text.
- Hello: `1|H|<addonVersion>` — capability discovery, not correlated with chat.
- Composer sends the addon message (when the chat type allows it) **before**
  `SendChatMessage`, then locally echoes the payload into the correlate cache
  so `/ct self` can exercise Tier 1 without a second client.
- SAY / YELL / public CHANNEL send only visible text; receivers use Tier 2.

## Alternatives considered

- **JSON payloads** — heavier, and Lua 5.1 has no `json` library.
- **Delay the chat filter until a payload arrives** — filters cannot yield;
  a miss already falls back to phrase matching of the visible line.
- **Put the phrase ID in the visible text** — ugly for non-users, and SAY
  still cannot carry a hidden channel.

## Consequences

- `Comm/Protocol.lua` is the only encoder/decoder. Bump the version integer
  (and this ADR) on a breaking change; keep v1 readable while v1 clients exist.
- Transport is AceComm (ADR-0004) plus a lockdown check. Chunking is AceComm's
  job; keep a single phrase well under 255 bytes so it stays one frame.
- Correlation can miss if the addon message is delayed; Tier 2 covers that
  for any phrase the visible text still matches.
