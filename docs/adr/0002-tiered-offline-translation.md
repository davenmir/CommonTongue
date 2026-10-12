# ADR-0002: Tiered offline translation (protocol, phrase, gloss)

- Status: Accepted
- Date: 2026-10-11
- Deciders: Emme (user)

## Context

Under ADR-0001 translation must happen inside the addon. Neural models are not
viable: models are tens to hundreds of MB, Lua 5.1 is interpreted with no
native math, and the client kills long-running scripts. However, a large share
of WoW chat is formulaic (LFG, trade, raid calls, courtesy, abbreviations), and
links (items, spells, quests) are already localized by the client.

## Decision

Use three tiers, tried in order:

1. **Protocol** — between CommonTongue users, send language-neutral phrase IDs
   via addon messages; receivers render in their own language. Exact.
2. **Phrase** — pattern-match incoming text against curated per-language phrase
   tables with typed parameters; render in the target language. High accuracy
   for covered phrases.
3. **Gloss** — word-by-word dictionary hints, shown on hover and explicitly
   labeled approximate. Never presented as a translation.

## Alternatives considered

- **Word-by-word substitution as the primary output** — produces misleading
  output; demoted to an opt-in hover aid.
- **Embedded statistical/neural MT** — infeasible in the sandbox.

## Consequences

- Phrase data and its review process are first-class deliverables.
- The UI must distinguish tiers visually.
- Tier 1 only works where addon messages can be delivered (see ARCHITECTURE §6).
