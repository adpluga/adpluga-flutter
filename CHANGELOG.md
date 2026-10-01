# Changelog

All notable changes to the AdPluga Flutter SDK are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.7.3] — 2026-10

### Added
- `example/`: a banner and an interstitial with the public demo key.
- Documentation on the public API.

### Changed
- Licensed under the Apache License 2.0. The previous licence pointed to terms
  at adpluga.com/legal/sdk-license that were never published, so it granted no
  clear right to use the SDK.
- `homepage` points to the SDK documentation; pub.dev topics added.

### Fixed
- The SDK reported itself as 0.7.1 to the server while the package was 0.7.2.
  The reported version now matches the package, so the minimum-version gate
  and telemetry see the real one.
- `ConsentState.gdpr` and `tcfString` were stored but never sent, so mediation
  bid requests left without them. They now go with every ad request (`gdpr=1`
  and the `X-Consent-String` header).

## [0.7.2] — 2026-09

### Added
- `alt_text` on the served creative, announced in place of the image. An ad is
  never decorative — it carries meaning and opens a destination — so rendering
  it unlabelled left the tap target with no accessible name at all, failing
  WCAG 2.2 SC 1.1.1 and SC 2.4.4 (both level A). Where the advertiser wrote no
  alternative text the renderer falls back to the creative's title, and a
  carousel card with no copy of its own inherits the ad's label.

## [0.7.1] — 2026-09

### Fixed
- A slot that failed to fill stayed blank for the rest of the session. Only the
  success path armed the next attempt, so a transient miss — or a widget that
  mounted before the SDK was initialised — cost the publisher that slot until
  the view was recreated. Every failure path now schedules another attempt,
  backing off exponentially from the client's cadence floor up to five minutes.
  Retry is independent of the slot's rotation cadence, which is off by default:
  tying recovery to rotation is what made a single miss permanent.

## [0.7.0] — 2026-09

### Fixed
- Impressions are no longer counted for a slot the host is not painting. The
  viewability check was pure geometry, so a banner on a hidden `IndexedStack`
  page or inside a collapsed viewport kept a valid rect and billed as fully
  viewable. It now consults `Visibility.of` and every ancestor paint clip,
  matching what the Android and iOS SDKs already did.
- Tapping an image creative now opens the advertiser destination. HTML and
  video creatives always did; image ones reported the click and went nowhere,
  so the advertiser paid for a tap that never arrived.
- `initialize` with a **different** publisher key now fails instead of quietly
  returning the existing instance. Rotating a key revokes the previous one at
  once, so the silent path left an app serving with a dead key. The same key
  stays idempotent; call `destroy()` first to re-initialize deliberately.
- `conversion()` sent `type`/`value`; the API reads `conv_type`/`value_cents`,
  so both were dropped. The old argument names still work, deprecated.

### Changed
- Without an explicit `width`/`height`, the banner now adopts the served
  creative's aspect ratio instead of pinning the box to its pixel size, so the
  fit is exact and a creative wider than the screen no longer overflows. A host
  that passes both dimensions still wins.
- `endpoint` accepts null to mean "use the default", and `kDefaultEndpoint` is
  exported, so a host reading the endpoint from configuration no longer has to
  hardcode an AdPluga hostname.

## [0.6.0] — 2026-09

### Added
- `AdPlugaCarousel` renders `type=carousel` decks in a `PageView`. The deck is
  one advertiser and one auction: every card reports the same click and no card
  triggers another serve, so swiping costs no decisions and no extra impression.
- `Slide` model and `Ad.slides`, parsed in the order the advertiser arranged;
  a slide without a creative is dropped rather than drawn blank.

### Changed
- A scheduled rotation now backs off while the reader is swiping the deck and
  resumes one full cadence after the last swipe.
- A slot cadence below the client floor is raised to it instead of being
  ignored, so a slot set to 15s rotates every 15s on a `pk_test_` key and every
  30s on a live one — it never stops rotating.

## [0.5.1] — 2026-09

### Fixed
- Frequency capping and first-party audiences now work on mobile. The SDK
  releases a first-party install id as `u` (the parameter the server actually
  reads) whenever the consent state allows personalisation; without consent no
  id leaves the device and the server skips both gates, as before.
- The id lives in memory for the process lifetime; pass `userHash` explicitly
  to key the daily cap across app launches.

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
