# CommonTongue — Product Vision

## 1. Problem

WoW players share realms, groups, and queues with people who speak other
languages (especially on EU realms and in cross-realm content). Chat in a
language you can't read means missed invites, failed coordination, and lost
friendships. Players today alt-tab to a web translator, or just ignore it.

## 2. Product statement

CommonTongue lets a player choose a **target language** and then understand,
and be understood in, in-game chat across languages — with **nothing to install
but the addon**.

## 3. Core constraint and what it implies

WoW addons cannot access the internet (ADR-0001). Therefore CommonTongue cannot
call Google Translate or any other service, and cannot run neural translation
models. Instead it uses three offline techniques, from most to least accurate
(ADR-0002):

| Tier | Technique | Accuracy | Works with |
|---|---|---|---|
| 1. Protocol | Sender's addon transmits language-neutral phrase IDs; receiver renders them in their own language | Exact | Other CommonTongue users |
| 2. Phrase | Pattern-match common WoW chat (LFG, trade, raid calls, courtesy, abbreviations) and render from curated phrase tables | High, for covered phrases | Anyone |
| 3. Gloss | Word-by-word dictionary hints on hover, clearly marked approximate | Low, a reading aid only | Anyone |

Free-form conversation that matches no phrase gets at most a Tier 3 gloss. The
product must be honest about this in UI and store descriptions.

On Retail, Blizzard's chat messaging lockdown makes chat text unreadable to
addons and blocks addon-sent messages during Mythic+ runs, PvP matches and boss
encounters, and possibly anywhere inside dungeons and raids
(`ARCHITECTURE.md` §1.1). In those situations CommonTongue cannot translate or
send anything; it must say so rather than fail silently.

## 4. Goals

- **G1** — Detect the language of incoming chat messages, offline.
- **G2** — Translate common WoW chat phrases accurately into the target language.
- **G3** — Exact, lossless cross-language messaging between CommonTongue users.
- **G4** — Help outgoing communication: a quick-phrase composer so a player can
  send phrases that others will see in their own language.
- **G5** — Give a reading aid (gloss) for uncovered text, clearly labeled.
- **G6** — Zero noticeable performance cost in busy chat (Trade, raids).
- **G7** — Retail first; architecture ready for Classic Era, progression Classic,
  and future flavors without rewrites (ADR-0003).
- **G8** — Make language data easy for the community to contribute and review.

## 5. Non-goals

- Translating arbitrary free text with high accuracy (not possible offline).
- Any companion app, browser extension, or external service (ADR-0001).
- Translating Blizzard UI, quest text, or NPC dialog (the client already
  localizes these).
- Voice chat.
- Moderation / profanity filtering beyond what phrase data incidentally covers.

## 6. Users and scenarios

- **EU pug player** (German client) joins a group whose leader types Spanish.
  `LFM Tank y healer para +10` is shown as a German line, marked as phrase
  translation.
- **Guild with mixed languages**: all members run CommonTongue; ready-check
  calls, "pull in 10", "bio break" sent from the composer are shown exactly in
  each member's language.
- **Trade chat browser**: sees a Russian WTS message; item links already render
  in their client language, and the surrounding phrase ("WTS", price) is
  translated.
- **Casual chatter**: an uncovered sentence shows a small language tag; hovering
  shows word glosses labeled "approximate".

### Supported languages (WoW client locales)

enUS/enGB, deDE, esES, esMX, frFR, itIT, ptBR, ruRU, koKR, zhCN, zhTW.
The first release ships English plus at least one other language pair, chosen
in ADR-0005 (pending, M3).

## 7. Milestones

Agents work only in the current milestone (marked **CURRENT**). Check boxes as
tasks complete. Do not start the next milestone without user confirmation.

### M0 — Feasibility spike **(CURRENT)**
Goal: confirm the platform facts the design depends on. Output is findings
recorded in `ARCHITECTURE.md` §9 (open questions) and ADRs, not shipping code.
- [ ] Confirm chat message filtering/rewriting via `ChatFrame_AddMessageEventFilter`
      (or its current Retail equivalent) works for all target chat events.
      *API identified from documentation (`ChatFrameUtil.AddMessageEventFilter`);
      in-game check pending.*
- [ ] Determine Retail "secret value" restrictions on chat message contents
      (which contexts, which events) and how to detect them.
      *Events and detection documented; whether lockdown covers entire
      dungeon/raid maps needs an in-game check.*
- [x] Confirm addon message limits on Retail: prefix length, payload size,
      throttling, and which chat types accept addon messages (PARTY, RAID,
      INSTANCE_CHAT, GUILD, WHISPER, CHANNEL, SAY/YELL restrictions).
      *From documentation, see `ARCHITECTURE.md` §6.*
- [x] Measure memory and load-time cost of a ~1 MB Lua data table.
      *545 ms, ~4.6 MB; see `ARCHITECTURE.md` §9.*
- [x] Decide embedded library set (ADR-0004).

### M1 — Skeleton
- [ ] Addon folder, Retail TOC, namespace bootstrap, event dispatcher.
- [ ] Compat layer stub with flavor detection.
- [ ] SavedVariables with defaults and migrations; slash command `/ct`.
- [ ] Settings panel: target language, enable/disable per chat type.
- [ ] Tooling: `.luacheckrc`, `.stylua.toml`, busted harness with WoW stubs, CI.

### M2 — Text foundations
- [ ] UTF-8 helpers (iterate codepoints, length, safe truncate).
- [ ] Normalizer (case-folding where safe, strip color codes / links into
      placeholders, collapse repeated letters).
- [ ] Language detector (script ranges + n-gram scoring for Latin-script
      languages) with confidence score.

### M3 — Phrase engine (Tier 2)
- [ ] Phrase data format and validator tool.
- [ ] Pattern matcher with parameter slots (role, number, gold amount, link).
- [ ] Renderer: phrase ID + params → target language string.
- [ ] Chat display: translated line rendering, visual marking, original on hover.
- [ ] First language pair data (ADR-0005), common LFG/trade/raid/courtesy phrases.

### M4 — CommonTongue protocol (Tier 1) and composer
- [ ] Wire format v1 and encoder/decoder (ADR required).
- [ ] Correlate addon messages with visible chat lines.
- [ ] Quick-phrase composer UI.
- [ ] Peer capability discovery (who in group runs CommonTongue, which version).

### M5 — Gloss fallback (Tier 3)
- [ ] Glossary data format, lookup, hover tooltip marked "approximate".

### M6 — Retail 1.0 release
- [ ] Performance pass under load (simulated Trade spam).
- [ ] Packaging, CurseForge / Wago / WoWInterface listings, README for users.
- [ ] Community contribution guide for language data.

### M7 — Classic flavors
- [ ] Classic Era / progression Classic TOCs and compat-layer implementations.
- [ ] Flavor-specific phrase data (e.g. dungeon names).

## 8. Success measures

- Phrase coverage: ≥ 60% of LFG/Trade lines in a captured sample matched by
  Tier 2 for each shipped language (measured with `tools/` against chat logs).
- Zero Lua errors and zero taint reports in a release candidate's test pass.
- Chat filter cost < 0.1 ms median per message on a mid-range PC.
