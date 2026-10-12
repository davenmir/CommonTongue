# In-game verification checklist

Record each result as: date, build (`/dump select(4, GetBuildInfo())`), flavor,
outcome, notes. Items here cannot be verified by agents.

## M0 — Feasibility spike (Retail)

### Results

| Date | Build | Flavor | Check | Outcome |
|---|---|---|---|---|
| 2026-10-11 | 120100 | Retail | CTSpike loads; filter API | Loads cleanly; `ChatFrameUtil.AddMessageEventFilter` present |
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
