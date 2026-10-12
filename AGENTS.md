# AGENTS.md — Operating Manual for CommonTongue

This repository is developed primarily by AI agents. This file is the entry point:
read it fully before doing any work, then read the documents it points to.

## 1. What we are building

CommonTongue is a World of Warcraft addon that helps players who speak different
languages understand each other in chat. It is **addon-only**: the addon is the
single thing a user installs. There is no companion app, no web service, and no
external translation API. See `docs/VISION.md` for the full product definition.

## 2. Document map

| Document | Purpose | Read when |
|---|---|---|
| `AGENTS.md` | How agents work in this repo | Always, first |
| `docs/VISION.md` | Goals, non-goals, features, milestones | Before picking up any task |
| `docs/ARCHITECTURE.md` | Components, data flow, module layout | Before writing code |
| `docs/adr/` | Architecture Decision Records | Before changing anything structural |
| `docs/CONVENTIONS.md` | Lua / WoW API coding rules | Before writing code |
| `docs/TESTING.md` | Test strategy, CI, packaging, release | Before opening a PR |

If documents disagree, precedence is: accepted ADRs > `ARCHITECTURE.md` >
`CONVENTIONS.md` > `VISION.md` > code comments. Fix the disagreement in the same
change that discovers it.

## 3. Hard constraints (never violate)

1. **No network, no external processes.** The WoW addon sandbox has no HTTP,
   sockets, or runtime file I/O. Do not design features that assume otherwise,
   and do not propose a companion app (rejected in ADR-0001).
2. **No Terms-of-Service risk.** No automation of player input, no memory
   reading, no anything that would get a user's account actioned.
3. **No taint.** Never replace or modify Blizzard secure frames/functions.
   Use documented hooks (chat message event filters via `ns.Compat`,
   `hooksecurefunc`).
4. **Honest output.** Accurate phrase translations and approximate word glosses
   must be visually distinct. Never present a guess as a translation.
5. **Multi-flavor ready.** Retail is the first target, but all flavor-specific
   API access goes through the compat layer (`Core/Compat.lua`). No direct calls
   to flavor-divergent APIs from feature modules.
6. **No globals** other than the addon's single namespace table and the
   SavedVariables declared in the TOC.

## 4. Workflow for every task

1. **Locate the task** in the current milestone in `docs/VISION.md` §7.
   Do not start work from a later milestone unless the user says so.
2. **Read** the relevant sections of `ARCHITECTURE.md` and any ADRs it cites.
3. **Plan** briefly: files to touch, tests to add, docs to update.
4. **Branch** from `main`: `m<milestone>/<short-kebab-description>`
   (e.g. `m2/utf8-helpers`).
5. **Implement** following `docs/CONVENTIONS.md`. Keep changes scoped to the task.
6. **Test**: add or update unit tests; run lint and tests (`docs/TESTING.md` §3).
   For anything that touches the live client, add an entry to the in-game
   checklist and state clearly that in-game verification is still pending.
7. **Document**: update docs in the same change (see §6).
8. **Commit** using Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`,
   `refactor:`, `chore:`), scope optional: `feat(phrases): add LFM patterns`.
9. **Mark progress** in `docs/VISION.md` §7 (checkbox) when the task is done.

## 5. Definition of done

A task is done when all of these hold:

- [ ] Code follows `docs/CONVENTIONS.md`; `luacheck` passes with no new warnings.
- [ ] Unit tests cover the new logic and pass under Lua 5.1 semantics.
- [ ] No new globals; no taint-prone calls; no direct flavor-specific API use
      outside `Core/Compat.lua`.
- [ ] User-visible strings go through the locale table (`L["..."]`).
- [ ] Docs updated; ADR written if a structural decision was made.
- [ ] In-game verification either performed (and recorded) or explicitly listed
      as pending in the PR/commit description.

## 6. Keeping documents consistent

- **Structural decision** (new module, new dependency, data format change,
  protocol change, dropped feature): write an ADR in `docs/adr/` using
  `0000-template.md`, then update `ARCHITECTURE.md` to match.
- **New convention discovered** (e.g. a WoW API gotcha): add it to
  `CONVENTIONS.md` §"WoW API gotchas" with a one-line reason.
- **Scope change**: update `VISION.md`; never silently drop a goal.
- **Unverified WoW API facts**: mark them `> UNVERIFIED:` in docs until
  confirmed in a live client or against current Blizzard API documentation
  (e.g. warcraft.wiki.gg, Blizzard's `Blizzard_APIDocumentationGenerated`).
  Agents must not "upgrade" an unverified fact to verified without evidence.

## 7. When to stop and ask the user

- A hard constraint (§3) would need to bend.
- An ADR marked `Accepted` would need to change.
- In-game verification is required to proceed and cannot be simulated.
- Native-speaker review is needed for language data (agents may draft
  translations, but mark them `reviewed = false`; see `ARCHITECTURE.md` §5).
- A milestone is complete — summarize and confirm before starting the next.

## 8. Repository layout (target)

```
CommonTongue/
├─ AGENTS.md
├─ README.md
├─ .pkgmeta                  # BigWigs packager config
├─ .luacheckrc
├─ .stylua.toml
├─ .busted                   # busted config
├─ .github/workflows/        # CI and release
├─ CHANGELOG.md              # Keep a Changelog format
├─ CommonTongue/             # the shippable addon folder
│  ├─ CommonTongue_Mainline.toc
│  ├─ CommonTongue_Vanilla.toc   # added in classic milestone
│  ├─ Core/                  # namespace, compat, events, db, utf8
│  ├─ Engine/                # detection, phrase engine, glossary
│  ├─ Comm/                  # addon-to-addon protocol
│  ├─ UI/                    # chat rendering, composer, settings
│  ├─ Locales/               # addon UI strings (L table)
│  ├─ Data/                  # phrase packs and glossaries per language
│  └─ Libs/                  # embedded libraries (via .pkgmeta externals)
├─ tests/                    # busted specs + WoW API stubs
│  └─ ingame/CHECKLIST.md    # manual in-game verification log
├─ samples/chat/             # anonymized chat lines for coverage
├─ tools/                    # data validation / generation scripts
└─ docs/
   ├─ VISION.md
   ├─ ARCHITECTURE.md
   ├─ CONVENTIONS.md
   ├─ TESTING.md
   └─ adr/
```
