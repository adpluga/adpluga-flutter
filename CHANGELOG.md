# Changelog

All notable changes to the AdPluga Flutter SDK are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.5.0] — 2026-09

### Added
- Slot rotation: banners now re-serve on the cadence the publisher configures
  for the slot (`refresh_after_seconds` on the serve response). Long-lived app
  screens no longer show a single frozen creative — the mobile equivalent of a
  web page reload.
- Rotation is gated so it cannot waste the publisher's budget or produce
  non-viewable impressions: it only fires while the ad meets the IAB pixel
  threshold and the app is in the foreground, is floored at 30s
  (`kMinRefreshSeconds`), and the timer is cancelled on dispose and while
  backgrounded.
- Each rotation sends its index (`rq`) so refreshed impressions stay
  segregable from the initial render, as the MRC guidelines require.

## [0.4.1] — 2026-08

### Added
- Test-mode badge: creatives served by a `pk_test_` (sandbox) key now render a
  small non-interactive "TEST" marker at the top-left of every ad surface
  (banner, native, HTML, video, interstitial, rewarded). Driven by the new
  `test` boolean on the serve response `ad` object (`Ad.isTest`). The badge is
  wrapped in `IgnorePointer` so it never intercepts taps.

## [0.4.0] — 2026-07

### Added
- Audio and video_rewarded ad kinds render via `AdPlugaVideo` widget in
  `AdPlugaBanner`, enabling autoplay for all video/audio formats.

### Fixed
- QuartileFirer now resolves relative ping URLs against the SDK endpoint,
  fixing quartile tracking when the backend returns relative paths.
- Fixed `AdPluga.maybeInstance?.endpoint` → `AdPluga.maybeInstance?.config.endpoint`
  in `AdPlugaVideo` widget (2 occurrences).

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
