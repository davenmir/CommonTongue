# In-game verification checklist

Record each result as: date, build (`/dump select(4, GetBuildInfo())`), flavor,
outcome, notes. Items here cannot be verified by agents.

## M0 — Feasibility spike (Retail)

- [ ] **Chat filter rewrite.** Register a filter with
      `ChatFrameUtil.AddMessageEventFilter` that appends a marker to `text` for
      SAY, YELL, PARTY, PARTY_LEADER, RAID, RAID_LEADER, INSTANCE_CHAT,
      INSTANCE_CHAT_LEADER, GUILD, OFFICER, WHISPER, BN_WHISPER and CHANNEL
      (Trade/General). The marker appears in every chat frame showing them.
- [ ] **lineID stability.** The same message shows the same `lineID` (arg 11)
      in every chat frame's filter call.
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
      used `secret*RestrictionsForced`).
- [ ] **Addon messages under lockdown.** `C_ChatInfo.SendAddonMessage` returns
      `AddOnMessageLockdown` (11) in each situation above where lockdown is true.
- [ ] **Data table cost.** Load a generated ~1 MB Lua table; record
      `GetAddOnMemoryUsage` after `UpdateAddOnMemoryUsage()` and login time with
      and without it.
