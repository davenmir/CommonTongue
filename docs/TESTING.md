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
  registration, `C_ChatInfo`, `ChatFrameUtil.AddMessageEventFilter`,
  `GetLocale`, `WOW_PROJECT_ID`, string helpers (`strtrim`, `wipe`, ...).
  `install()` resets all globals and returns a `state` table: `state.fire(event,
  ...)` drives events; `state.errors`, `state.printed`, `state.filters` record
  effects; `state.inCombat`, `state.lockdown`, `state.locale` control the client.
- Real LibStub, CallbackHandler and AceDB are loaded from `CommonTongue/Libs`.
  AceGUI and AceConfig need a real client, so the loader replaces them with
  fakes that record the registered options table.
- Secret values: the stub provides `issecretvalue` and a way to mark a test
  string as secret, so specs can assert the chat filter passes it through
  without touching it.
- `tests/helpers/loader.lua` loads addon files in TOC order (expanding library
  `.xml` includes) with a shared `ns`, emulating `local _, ns = ...`.
  `loader.load({ files = {...} })` loads a subset; `loader.login()` loads all
  and fires `ADDON_LOADED` + `PLAYER_LOGIN`.
- Stubs implement only what tests need; extend them alongside tests.
- `Engine/` must be testable without stubs beyond `ns.UTF8` and data loading.

## 3. Commands

```bash
python3 tools/fetch_libs.py # once: embedded libraries into CommonTongue/Libs
tools/check.sh              # luacheck + busted, as CI runs them
stylua --check .
lua tools/validate_data.lua                 # from M3
lua tools/coverage.lua samples/chat/*.txt   # from M3, phrase coverage report
```

Local setup on Windows (what the maintainer uses):

```powershell
wsl -d Ubuntu -- sudo apt-get install -y lua5.1 liblua5.1-0-dev luarocks build-essential
wsl -d Ubuntu -- luarocks --lua-version=5.1 --local install busted
wsl -d Ubuntu -- luarocks --lua-version=5.1 --local install luacheck
wsl -d Ubuntu -- bash tools/check.sh
tools\bin\stylua.exe --check .   # StyLua v2.6.0 Windows binary, gitignored
```

For in-game testing, link the addon folder into the client:
`New-Item -ItemType Junction -Path "<WoW>\_retail_\Interface\AddOns\CommonTongue"
-Target "<repo>\CommonTongue"` (libraries must be fetched first).
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

On every push and PR (`.github/workflows/ci.yml`): fetch libraries, luacheck,
stylua check, busted. Data validation joins in M3.
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
