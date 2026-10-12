# CommonTongue — Coding Conventions

## 1. Language and runtime

- Target **Lua 5.1** semantics (WoW's runtime). Do not use `goto`, integer
  division `//`, bitwise operators, `utf8.*`, or `table.unpack` (use `unpack`).
- WoW extras that are safe to use: `strsplit`, `strjoin`, `strtrim`, `wipe`,
  `tinsert`/`tremove`, `strlenutf8`, `C_Timer`, and the `bit` library
  (`bit.band`, `bit.bor`, `bit.bxor`, ...) in place of bitwise operators. Access them via locals at file
  top so unit-test stubs can replace them.

## 2. File structure

Every Lua file starts with:

```lua
local _, ns = ...
local Module = ns:NewModule("ModuleName") -- or: local Module = ns.ModuleName

-- upvalue frequently used globals
local pairs, type, strfind = pairs, type, string.find
```

- One module per file. File name matches module name.
- Order: header → local upvalues → private helpers (`local function`) →
  public API (`function Module:Method()` / `function Module.Func()`) → event
  registration at the bottom.
- Load order is defined only by the TOC; keep it identical across flavor TOCs
  except for `Compat_<Flavor>.lua` lines.

## 3. Naming

| Kind | Style | Example |
|---|---|---|
| Modules / classes | PascalCase | `Phrase`, `ChatFilter` |
| Public functions | PascalCase | `Phrase:Match(tokens)` |
| Locals / private functions | camelCase | `local function buildIndex()` |
| Constants | UPPER_SNAKE | `MAX_PAYLOAD_BYTES` |
| Phrase IDs | UPPER_SNAKE | `LFM_ROLES` |
| Locale codes | WoW format | `deDE`, `ptBR` |
| SavedVariables | `CommonTongueDB` (account-wide, via AceDB; per-character data uses AceDB's `char` section, so no separate per-character file) |

## 4. Globals and namespace

- No new globals. All shared state lives on `ns`. Exceptions are listed in
  `AGENTS.md` §3.6 (SavedVariables, slash command registration).
- Debug access in-game: `/ct debug` exposes `ns` as `CommonTongue` only while
  debug mode is on.
- `luacheck` enforces this; the allowed WoW globals list lives in `.luacheckrc`.

### Module lifecycle

- `ns:NewModule(name)` registers a module; modules run in TOC load order.
- `Module:OnInitialize()` runs once on this addon's `ADDON_LOADED`
  (SavedVariables ready). `Module:OnEnable()` runs once on `PLAYER_LOGIN`.
- Both are called through `ns.Compat.SafeCall`, so one module's error is
  reported (BugSack) without stopping the others.

## 5. WoW API usage

- Flavor-divergent APIs go through `ns.Compat` (ADR-0003). If unsure whether an
  API differs between flavors, route it through Compat.
- Chat modification only via message event filters and `hooksecurefunc`.
  Never overwrite Blizzard functions or frame scripts.
- Register events through `ns.Events`, not by creating ad-hoc frames.
- Never call protected functions; never act from combat-locked code paths.
- Guard every `C_*` access in Compat with existence checks so older flavors
  don't error at load time.

## 6. Strings and text

- User-visible UI strings go through `L["English text"]`. Keys are the enUS
  text; `Locales/enUS.lua` declares every key as `L["..."] = true`, and a test
  fails if code uses a key that enUS doesn't declare. Missing translations fall
  back to the key.
- Translation data (phrases, glossaries) lives in `Data/`, never in `Locales/`.
- Treat all chat text as UTF-8 bytes. Use `ns.UTF8` helpers for anything
  length- or position-based. Never slice a string mid-codepoint.
- Preserve escape sequences (`|c...|r` colors, `|H...|h...|h` links, `|T...|t`
  textures) by tokenizing them into placeholders before processing and
  restoring them after.

## 7. Performance

- Hot path = anything run per chat message. In hot paths: no closures created
  per call, minimal table allocation, early returns first.
- Precompute indexes lazily, once per language.
- Use `debugprofilestop()` around new hot-path code during development; record
  numbers in the PR description.

## 8. Error handling

- Feature code must never throw into Blizzard's chat pipeline. The chat filter
  wraps the pipeline in `pcall`; on error it passes the message through
  unmodified and logs once per error signature (debug mode only).
- Validate data packs at load in debug mode; in release mode skip invalid
  entries rather than error.

## 9. Formatting and comments

- Formatting by StyLua (`.stylua.toml`): 4-space indent, 100 columns,
  double quotes.
- Comments explain constraints the code can't show (WoW quirks, limits),
  not what the next line does.
- LuaLS annotations (`---@param`, `---@return`, `---@class`) on public API.

## 10. Data files

- One language per folder: `Data/<locale>/Phrases.lua`, `Data/<locale>/Gloss.lua`.
- Patterns lowercase; the normalizer lowercases input where the language
  allows it.
- Every pack declares `reviewed = true|false`. Agents set `false`.
- Run `tools/validate_data.lua` after any data change.

## 11. WoW API gotchas

Append entries here as they are discovered: `- <API/behavior> — <why it matters>`.

- Chat filters run once per chat frame showing the event — results must be
  cached to avoid repeated work and inconsistent output.
- SavedVariables are not available until `ADDON_LOADED` for this addon fires.
- Retail chat text can be a secret value (ARCHITECTURE §1.1) — check
  `issecretvalue(text)` before any string op; comparing or `strfind`-ing a
  secret is an immediate Lua error. `if text then` is allowed.
- Retail chat filters are registered via `ChatFrameUtil.AddMessageEventFilter`;
  the `ChatFrame_*` global is a deprecated alias — go through `ns.Compat`.
- `C_ChatInfo.SendChatMessage` on SAY/YELL/CHANNEL requires a hardware event —
  only send from a click/keypress handler.
