# ADR-0001: Addon-only distribution, no external services

- Status: Accepted
- Date: 2026-10-11
- Deciders: Emme (user)

## Context

The original idea was to use a service such as Google Translate. WoW addons run
in a sandboxed Lua 5.1 environment with no network access, no process
execution, and no runtime file I/O. SavedVariables are only read at login and
written at logout or `/reload`. Any online translation would therefore require a
separate desktop companion app that reads the chat log and displays results in
an overlay or feeds them back in some way.

## Decision

CommonTongue is addon-only. Users install exactly one thing: the addon. No
companion app, overlay, browser extension, or external service will be built,
now or later.

## Alternatives considered

- **Companion app + overlay** — full machine translation quality, but a second
  install, API keys/costs, OS-specific code, and outside the user's intent.
- **Companion app feeding data back via SavedVariables** — needs `/reload` per
  update; unusable for live chat.
- **Input automation / memory reading** — ToS violation risk; rejected outright.

## Consequences

- Arbitrary free-text translation with high accuracy is out of scope.
- Translation is delivered through offline tiers (ADR-0002).
- Language data quality and coverage become the core of the product.
