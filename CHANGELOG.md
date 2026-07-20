# Changelog

All notable changes to the AdPluga Flutter SDK are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.3.0] — 2026-07

### Added
- IAB viewability dispatch: `AdPluga.fireViewable(resp, slotId)` posts
  `/v1/track/viewable` with the served track token. Banner, native,
  interstitial and rewarded widgets fire it from the same viewability
  callback that already recorded the impression.

## [0.2.0] — 2025-11

### Added
- HTML5 / WebView ad format via `webview_flutter`.
- Video and rewarded video formats via `video_player` with VAST-style
  quartile beacons.
- URL sandboxing for embedded creatives (only `http`/`https` schemes).

### Changed
- Mandatory `AdPluga.initialize` gate — SDK operations now throw a clear
  `StateError` if invoked before initialization.

## [0.1.0] — 2025-10

### Added
- Initial public release: banner, native, and interstitial formats.
- HTTP client, viewability tracker, click tracking, and consent adapter.
