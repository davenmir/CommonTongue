# In-game verification checklist

Record each result as: date, build (`/dump select(4, GetBuildInfo())`), flavor,
outcome, notes. Items here cannot be verified by agents.

## M4 — Protocol and composer (Retail)

Needs two clients for the exact-translation checks. Solo items work with
`/ct self` in a party (or a whisper to a friend).

- [ ] `/ct compose` opens the phrase window. Click **Send** on THANKS in SAY:
      the visible line is your client language. Hover still unused for SAY
      (no addon channel). BugSack empty.
- [ ] In a party, Send THANKS: the other CommonTongue user sees `[CT→…]` in
      their target language, hover shows your original. A player without the
      addon sees your client-language text.
- [ ] `/ct peers` lists the other user after they are grouped with you.
- [ ] Whisper a parameterized LFM_ROLES line (tank + healer, +10) to a second
      CommonTongue user: roles and activity render in their language.
- [ ] Force lockdown (`addonChatRestrictionsForced 1`): composer status says
      it can't send; no Lua errors.
- [ ] `/ct compose` in combat prints that it can't open.

## M3 — Phrase engine (Retail)

Requires M1 setup. Turn on **Translate my own messages** (`/ct self`) so you
can test alone.

- [ ] `/ct self` then `/say LFM Tank y healer para +10` shows an English line
      marked `[es→en]` (or German if that is the target), plus `(unreviewed)`.
- [ ] `/say Suche Tank und Heiler für +10` becomes `LFM tank and healer for +10`
      when the target language is English.
- [ ] Hover the translated text: tooltip shows the original.
- [ ] `/say looking for tank and healer for the key` is left unchanged when
      the target is English.
- [ ] `/say was für ein schöner Sonnenuntergang heute` stays German and gets a
      `[de]` tag, not a fake translation.
- [ ] `/ct self` off: your own `/say` lines are no longer rewritten.
- [ ] No Lua errors (BugSack empty) while chatting in SAY, whisper, and a
      channel. Group chat still pending a second player.

## M1 — Skeleton (Retail)

Setup: `python tools/fetch_libs.py`, then link `CommonTongue/` into
`_retail_/Interface/AddOns/` (see `docs/TESTING.md` §3).

- [ ] Addon loads with no Lua errors (BugSack empty) and appears in the AddOns
      list as "CommonTongue".
- [ ] `/ct` opens the CommonTongue page in the game's Settings window.
- [ ] `/ct` during combat prints "Settings can't be opened in combat." and
      does not open anything or cause errors.
- [ ] Target language dropdown lists "Same as game client (English)" first,
      then all 11 languages in their own scripts (Русский, 한국어, 简体中文 render).
- [ ] Changing target language and toggling chat types survive `/reload` and
      a full relog.
- [ ] `/ct version` prints a version and `Mainline`. (Unpackaged dev builds show
      `@project-version@`.)
- [ ] `/ct debug` then `/dump CommonTongue.DB:Profile()` shows settings;
      `/ct debug` again makes `CommonTongue` nil.
- [ ] `/ct nonsense` prints the help list.

## M0 — Feasibility spike (Retail)

### Results

| Date | Build | Flavor | Check | Outcome |
|---|---|---|---|---|
| 2026-10-11 | 120100 | Retail | CTSpike loads; filter API | Loads cleanly; `ChatFrameUtil.AddMessageEventFilter` present |
| 2026-10-11 | 120100 | Retail | Data table cost | 1,098,047 bytes / 6,000 entries / 18,000 patterns: `LoadAddOn` 544.7 ms, 4,677 KB addon memory (heap +3,621 KB); first-token index 5.9 ms, 647 KB |
| 2026-10-11 | 120100 | Retail | Chat filter rewrite (SAY) | Marker shown in ChatFrame1 |
| 2026-10-11 | 120100 | Retail | Chat filter rewrite (other types) | User-reported: marker shown on the other chat types tried, with EllesmereUIChat on. Group chat (party/raid/instance) not yet exercised |
| 2026-10-11 | 120100 | Retail | EllesmereUIChat interaction | With EllesmereUIChat on, `/played` shows raw `\|4day:days;` grammar escapes; disabling it fixes this. Not caused by CTSpike (system messages are not filtered). Filter output is honored: SAY marker shown with it on and off, other chat types with it on |
| 2026-10-11 | 120100 | Retail | Forced chat lockdown (`addonChatRestrictionsForced 1`) | Setting fires `ADDON_RESTRICTION_STATE_CHANGED` with args `5, 1` (clearing: `5, 0`). `InChatMessagingLockdown()` = true; SAY text arrives secret; filter passes it through untouched with no Lua errors. Reproduced 3 times |
| 2026-10-11 | 120100 | Retail | Addon sends under forced lockdown | GUILD, WHISPER → `AddOnMessageLockdown`. PARTY/RAID/INSTANCE_CHAT → `NotInGroup` (group check runs before the lockdown check) |
| 2026-10-11 | 120100 | Retail | Open-world chat readable | SAY, WHISPER, WHISPER_INFORM, CHANNEL: `textSecret=false`, `lockdown=false` (open world, maps 2393/2395/2537) |

Tooling: the `CTSpike` test addon automates these checks.

1. Run `spikes/make_data_pack.ps1` once (generates the ~1 MB data pack).
2. Copy `spikes/CTSpike` and `spikes/CTSpike_Data` into
   `World of Warcraft/_retail_/Interface/AddOns/`.
3. In game, `/cts` lists commands. Chat lines get a grey `[cts <lineID>]`
   marker (`/cts markers` toggles it). Lockdown changes and the first chat
   message per channel and lockdown state print automatically.
4. Results are saved to
   `WTF/Account/<account>/SavedVariables/CTSpike.lua` on logout or `/reload`;
   share that file to record results here.

- [ ] **Chat filter rewrite.** Register a filter with
      `ChatFrameUtil.AddMessageEventFilter` that appends a marker to `text` for
      SAY, YELL, PARTY, PARTY_LEADER, RAID, RAID_LEADER, INSTANCE_CHAT,
      INSTANCE_CHAT_LEADER, GUILD, OFFICER, WHISPER, BN_WHISPER and CHANNEL
      (Trade/General). The marker appears in every chat frame showing them.
      *CTSpike: look for the marker, then `/cts events` lists each chat type the
      filter ran for and in which windows.* Also check: a newly created chat
      tab, a pop-out whisper window, and EMOTE, COMMUNITIES_CHANNEL, BN whispers.
- [ ] **lineID stability.** The same message shows the same `lineID` (arg 11)
      in every chat frame's filter call. *CTSpike: `/cts lines` with a channel
      shown in two chat tabs; expect `frames=` to list both.*
- [ ] **Lockdown scope.** Print `C_ChatInfo.InChatMessagingLockdown()` and
      `issecretvalue(text)` for PARTY/RAID chat in each situation:
      1. Inside a normal dungeon, out of combat, no encounter.
      2. Inside a Mythic 0 dungeon, out of combat, no encounter.
      3. Inside a Mythic+ dungeon before inserting the key.
      4. During a Mythic+ run, between pulls.
      5. In a raid between bosses.
      6. In a raid during a boss encounter.
      7. In a battleground before and after the match starts.
      Shortcut for early testing: CVars `addonChatRestrictionsForced`,
      `addonMapRestrictionsForced`, `addonEncounterRestrictionsForced`,
      `addonChallengeModeRestrictionsForced`, `addonPvPMatchRestrictionsForced`
      force each restriction type (names per the current wiki; older beta notes
      used `secret*RestrictionsForced`). *CTSpike: logs automatically; have a
      groupmate type in party chat at each step.*
- [ ] **Addon messages under lockdown.** `C_ChatInfo.SendAddonMessage` returns
      `AddOnMessageLockdown` (11) in each situation above where lockdown is true.
      *CTSpike: `/cts addon`.*
- [ ] **Data table cost.** Load a generated ~1 MB Lua table; record
      `GetAddOnMemoryUsage` after `UpdateAddOnMemoryUsage()` and load time.
      *CTSpike: `/cts data` right after a `/reload`.*
