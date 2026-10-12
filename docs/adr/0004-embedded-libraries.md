# ADR-0004: Embedded libraries

- Status: Accepted
- Date: 2026-10-11
- Deciders: Emme (user)

## Context

We need: SavedVariables defaults/profiles, a settings UI, throttled and chunked
addon messaging, and possibly a minimap/LDB launcher. The community-standard
libraries cover these and are maintained across flavors.

## Decision

Embed via `.pkgmeta` externals (not committed to the repo):

- `LibStub`, `CallbackHandler-1.0`
- `AceDB-3.0` — SavedVariables with defaults and profiles
- `AceComm-3.0` + `ChatThrottleLib` — chunked, throttled addon messages
- `AceConfig-3.0` / `AceConfigDialog-3.0` — settings panel from a table spec

Do not use `AceAddon`/`AceEvent` initially; our own small `Core/Init.lua` and
`Core/Events.lua` keep the core testable and dependency-light.

## Alternatives considered

- **No libraries** — more code to write and maintain for throttling and config UI.
- **Full Ace3 framework** — more convention than we need; heavier tests stubs.

## Consequences

- Tests must stub or load these libraries (`tests/stubs/`).
- Version pins in `.pkgmeta`.
- `Comm/Transport.lua` is a thin wrapper over AceComm; chunking and throttling
  are not reimplemented.
- AceComm sends fail during Retail chat messaging lockdown like any addon
  message (ARCHITECTURE §1.1); Transport must check lockdown before queueing.
