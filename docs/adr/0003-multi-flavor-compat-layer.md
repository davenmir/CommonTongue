# ADR-0003: Single codebase for all game flavors via a compat layer

- Status: Accepted
- Date: 2026-10-11
- Deciders: Emme (user)

## Context

Retail is the first target, but the user wants to support Classic Era,
progression Classic, and future flavors. APIs, chat events, and restrictions
differ between flavors (e.g. Retail secret values, namespaced `C_*` APIs that
may be missing in older clients).

## Decision

- One codebase. One TOC file per flavor using the standard suffixes
  (`_Mainline`, `_Vanilla`, `_Mists`, ...), so a single package installs on all.
- All flavor-divergent API usage goes through `Core/Compat.lua`, which detects
  the flavor via `WOW_PROJECT_ID` and exposes a stable internal API.
- Flavor-specific implementations live in `Core/Compat_<Flavor>.lua` and are
  listed only in that flavor's TOC.
- Feature modules (`Engine/`, `Comm/`, `UI/`) never call flavor-divergent APIs
  directly.

## Alternatives considered

- **Separate branches/addons per flavor** — duplicated effort, drift.
- **Runtime feature checks scattered through code** — hard to audit and test.

## Consequences

- Slight indirection cost; easy to test by stubbing `Compat`.
- Adding a flavor means: new TOC, new `Compat_<Flavor>.lua`, data tagging.
