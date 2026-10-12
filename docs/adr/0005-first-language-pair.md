# ADR-0005: First shipped language pair

- Status: Accepted
- Date: 2026-10-12
- Deciders: agent (user asked for M1–M3 without further input)

## Context

VISION.md §6 requires the first release to ship English plus at least one other
language pair. The documented EU pug scenario is Spanish LFG read by a German
client. Native-speaker review is not available yet, so any non-English data
must ship as `reviewed = false`.

## Decision

- Official first pair: **enUS ↔ deDE**.
- **esES** ships in the same milestone as unreviewed match/render data so the
  documented pug line (`LFM Tank y healer para +10`) works. It is not the
  official pair and may be dropped or rewritten after review.
- esMX shares esES match patterns for now (Latin American Spanish LFG slang is
  close enough for a first draft).
- Agent-drafted strings stay `reviewed = false`.

## Alternatives considered

- **enUS ↔ esES only** — covers the pug line, but the vision's German-client
  example would have nothing to render into.
- **Wait for native-speaker review** — blocks M3 entirely.

## Consequences

- `Data/enUS`, `Data/deDE`, and `Data/esES` load at startup. Memory stays well
  under the 1.1 MB / 4.6 MB ceiling measured in M0.
- UI may mark unreviewed translations (M3 uses a subtle "unreviewed" note in
  the hover tooltip).
