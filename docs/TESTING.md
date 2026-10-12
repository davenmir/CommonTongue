# CommonTongue — Testing and Release

## 1. Test layers

| Layer | What | Where | Runs in |
|---|---|---|---|
| Static | Lint (`luacheck`), format check (`stylua --check`) | whole repo | Local + CI |
| Unit | Pure logic in `Core/UTF8`, `Engine/*`, `Comm/Protocol` | `tests/unit/*_spec.lua` | busted, Lua 5.1 / LuaJIT |
| Integration | Chat pipeline end-to-end with stubbed WoW API | `tests/integration/*_spec.lua` | busted |
| Data | Language pack validation and coverage | `tools/validate_data.lua`, `tools/coverage.lua` | Local + CI |
| In-game | Real client behavior | `tests/ingame/CHECKLIST.md` | Manual, by the user |

Agents can run everything except the in-game layer. Any change whose
correctness depends on real client behavior must add or update an in-game
checklist item and be flagged as pending verification.

## 2. WoW API stubs

- `tests/stubs/wow.lua` provides minimal fakes: `CreateFrame`, event
  registration, `C_Timer`, `C_ChatInfo`, `ChatFrameUtil.AddMessageEventFilter`,
  `GetLocale`, `WOW_PROJECT_ID`, string helpers (`strsplit`, `strtrim`, ...).
- Secret values: the stub provides `issecretvalue` and a way to mark a test
  string as secret, so specs can assert the chat filter passes it through
  without touching it.
- `tests/helpers/loader.lua` loads addon files in TOC order with a shared `ns`,
  emulating `local _, ns = ...`.
- Stubs implement only what tests need; extend them alongside tests.
- `Engine/` must be testable without stubs beyond `ns.UTF8` and data loading.

## 3. Commands

```bash
luacheck .
stylua --check .
busted                      # all specs (config in .busted)
lua tools/validate_data.lua
lua tools/coverage.lua samples/chat/*.txt   # phrase coverage report
```

Local setup on Windows: install Lua 5.1 + LuaRocks (e.g. via `hererocks`) or run
in WSL; `luarocks install busted luacheck`. StyLua is a standalone binary.
CI is authoritative if local setup differs.

## 4. Test conventions

- One spec file per module: `tests/unit/<module>_spec.lua`.
- Language-data tests are table-driven: input line, expected phrase ID,
  expected params, expected rendered output per target language.
- Every bug fix adds a regression test reproducing it first.
- Include non-ASCII cases for anything touching text (Cyrillic, Hangul, CJK,
  accented Latin), plus links and color codes embedded in messages.

## 5. Chat samples

- `samples/chat/` holds anonymized chat lines (player names replaced) used for
  coverage measurement and integration tests. Never commit real player names.
- Users can capture samples via `/chatlog`; a script in `tools/` anonymizes them.

## 6. In-game checklist

`tests/ingame/CHECKLIST.md` lists scenarios to verify per release, per flavor,
e.g.: addon loads without errors; settings persist across `/reload`; party
message in another language is translated; protocol message renders for a
second client; no taint after combat; behavior inside a raid encounter
(secret values). Results recorded with date, build number, and flavor.

## 7. CI (GitHub Actions)

On every push and PR: luacheck, stylua check, busted, data validation.
On tag `v*`: run the BigWigs packager to build and upload to CurseForge, Wago,
WoWInterface, and GitHub Releases (API tokens in repository secrets).

## 8. Versioning and release

- SemVer: `MAJOR.MINOR.PATCH`. Protocol wire version is separate and only bumps
  on wire-format changes.
- TOC `## Version: @project-version@` is filled by the packager.
- `## Interface:` per flavor TOC must match the current client build; check with
  `/dump select(4, GetBuildInfo())` and update each patch.
- `CHANGELOG.md` updated in every user-visible change (Keep a Changelog format).
- Release flow: all CI green → in-game checklist completed for each shipped
  flavor → tag → packager publishes.
