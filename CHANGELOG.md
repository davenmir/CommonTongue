# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- UTF-8 helpers: code-point iteration, length, safe truncate, script class,
  case-folding for Latin and Cyrillic.
- Chat normalizer: strips colors, lifts links/textures into placeholders,
  lowercases, collapses long letter runs.
- Offline language detector (script ranges plus word/trigram scores for
  Latin-script locales).
- Tier 2 phrase engine: catalog, per-language match/render packs, typed
  parameters (roles, gold, numbers, links), chat filter pipeline.
- First language data: enUS (reviewed) plus unreviewed deDE and esES drafts
  (ADR-0005). Hover a translation to see the original; unreviewed output is
  marked.
- `/ct self` and a settings toggle to translate your own messages for solo
  testing.

- Addon skeleton for Retail: module lifecycle, event dispatcher, compat layer
  with flavor detection.
- Settings panel in the game's Settings window: enable/disable, target
  language (default: same as game client), and per-chat-type toggles.
- Slash commands: `/ct` (open settings), `/ct version`, `/ct debug`, `/ct help`.
  `/commontongue` works as an alias.
- Saved settings with schema versioning.
