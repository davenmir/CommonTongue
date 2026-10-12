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

- Addon skeleton for Retail: module lifecycle, event dispatcher, compat layer
  with flavor detection.
- Settings panel in the game's Settings window: enable/disable, target
  language (default: same as game client), and per-chat-type toggles.
- Slash commands: `/ct` (open settings), `/ct version`, `/ct debug`, `/ct help`.
  `/commontongue` works as an alias.
- Saved settings with schema versioning.
