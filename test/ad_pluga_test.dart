import 'dart:convert';

import 'package:adpluga_flutter/adpluga_flutter.dart';
import 'package:adpluga_flutter/src/client/transport.dart' as transport_seam;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await AdPluga.maybeInstance?.destroy();
    transport_seam.transportClientOverride = null;
  });

  test('initialize rejects invalid publisher key', () async {
    await expectLater(
      AdPluga.initialize(publisherKey: 'nope'),
      throwsA(isA<InvalidKeyError>()),
    );
  });

  test('fireViewable posts /v1/track/viewable with the served track token',
      () async {
    final trackCalls = <String>[];
    final trackBodies = <String>[];
    transport_seam.transportClientOverride = () => MockClient((req) async {
          if (req.url.path == '/v1/serve') {
            return http.Response(displayFixture, 200);
          }
          if (req.url.path == '/v1/features') {
            return http.Response(featuresFixture(), 200);
          }
          if (req.url.path.startsWith('/v1/track')) {
            trackCalls.add(req.url.path);
            trackBodies.add(req.body);
            return http.Response('', 204);
          }
          return http.Response('{}', 200);
        });

    final ad = await AdPluga.initialize(
      publisherKey: 'pk_test_abc',
      telemetryEnabled: false,
    );
    final resp = await ad.serve(slotId: 'slot_x');
    expect(resp, isNotNull);
    ad.fireViewable(resp!, 'slot_x');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(trackCalls, contains('/v1/track/viewable'));
    final idx = trackCalls.indexOf('/v1/track/viewable');
    final body = jsonDecode(trackBodies[idx]) as Map<String, Object?>;
    expect(body['token'], resp.trackToken);
    expect(body['event'], 'viewable');
  });

  test('serve returns response for pk_test_* key', () async {
    final serveCalls = <String>[];
    transport_seam.transportClientOverride = () => MockClient((req) async {
          if (req.url.path == '/v1/serve') {
            serveCalls.add(req.url.toString());
            return http.Response(displayFixture, 200);
          }
          if (req.url.path == '/v1/features') {
            return http.Response(featuresFixture(), 200);
          }
          return http.Response('{}', 200);
        });

    final ad = await AdPluga.initialize(
      publisherKey: 'pk_test_abc',
      telemetryEnabled: false,
    );
    final resp = await ad.serve(slotId: 'slot_x');
    expect(resp, isNotNull);
    expect(resp!.ad.kind, AdKind.image);
    expect(resp.source, AdSource.house);
    expect(serveCalls, hasLength(1));
  });

  test('serve parses test flag on the ad', () async {
    transport_seam.transportClientOverride = () => MockClient((req) async {
          if (req.url.path == '/v1/serve') {
            return http.Response(testModeFixture, 200);
          }
          if (req.url.path == '/v1/features') {
            return http.Response(featuresFixture(), 200);
          }
          return http.Response('{}', 200);
        });

    final ad = await AdPluga.initialize(
      publisherKey: 'pk_test_abc',
      telemetryEnabled: false,
    );
    final resp = await ad.serve(slotId: 'slot_x');
    expect(resp, isNotNull);
    expect(resp!.ad.isTest, isTrue);
  });

  test('serve defaults test flag to false when absent', () async {
    transport_seam.transportClientOverride = () => MockClient((req) async {
          if (req.url.path == '/v1/serve') {
            return http.Response(displayFixture, 200);
          }
          if (req.url.path == '/v1/features') {
            return http.Response(featuresFixture(), 200);
          }
          return http.Response('{}', 200);
        });

    final ad = await AdPluga.initialize(
      publisherKey: 'pk_test_abc',
      telemetryEnabled: false,
    );
    final resp = await ad.serve(slotId: 'slot_x');
    expect(resp, isNotNull);
    expect(resp!.ad.isTest, isFalse);
  });

  test('426 upgrade_required blocks further serves', () async {
    var attempts = 0;
    transport_seam.transportClientOverride = () => MockClient((req) async {
          if (req.url.path == '/v1/serve') {
            attempts++;
            return http.Response(
              jsonEncode({
                'error': 'upgrade_required',
                'platform': 'flutter',
                'required_version': '1.4.0',
              }),
              426,
              headers: {'x-adpluga-min-sdk': '1.4.0'},
            );
          }
          if (req.url.path == '/v1/features') {
            return http.Response(featuresFixture(), 200);
          }
          return http.Response('{}', 200);
        });

    final ad = await AdPluga.initialize(
      publisherKey: 'pk_test_abc',
      telemetryEnabled: false,
    );

    final events = <SdkEvent>[];
    final sub = ad.events.listen(events.add);

    final first = await ad.serve(slotId: 'slot_x');
    final second = await ad.serve(slotId: 'slot_x');

    expect(first, isNull);
    expect(second, isNull);
    expect(attempts, 1);
    expect(ad.isUpgradeBlocked, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(events.whereType<UpgradeRequiredSdkEvent>().length, 1);
    await sub.cancel();
  });

  test('consent non-personalized flag propagates on serve', () async {
    final params = <Map<String, String>>[];
    transport_seam.transportClientOverride = () => MockClient((req) async {
          if (req.url.path == '/v1/serve') {
            params.add(Map<String, String>.from(req.url.queryParameters));
            return http.Response(displayFixture, 200);
          }
          if (req.url.path == '/v1/features') {
            return http.Response(featuresFixture(), 200);
          }
          return http.Response('{}', 200);
        });

    final ad = await AdPluga.initialize(
      publisherKey: 'pk_test_abc',
      telemetryEnabled: false,
    );
    await ad.serve(slotId: 'slot_x');
    ad.setConsent(const ConsentState(gdpr: true, adPersonalization: false));
    await ad.serve(slotId: 'slot_x');

    expect(params.length, 2);
    expect(params[0].containsKey('non_personalized'), isFalse);
    expect(params[1]['non_personalized'], 'true');
  });

  test('serve sends the install id as u when personalised', () async {
    final params = <Map<String, String>>[];
    transport_seam.transportClientOverride = () => MockClient((req) async {
          if (req.url.path == '/v1/serve') {
            params.add(Map<String, String>.from(req.url.queryParameters));
            return http.Response(displayFixture, 200);
          }
          return http.Response(featuresFixture(), 200);
        });

    final ad = await AdPluga.initialize(
      publisherKey: 'pk_test_abc',
      telemetryEnabled: false,
    );
    await ad.serve(slotId: 'slot_x');
    await ad.serve(slotId: 'slot_x');

    // The backend keys frequency capping and first-party audiences on `u`;
    // without it both gates are skipped entirely.
    expect(params[0]['u'], isNotNull);
    expect(params[0]['u'], isNotEmpty);
    // Stable across serves so the daily cap actually accumulates.
    expect(params[1]['u'], params[0]['u']);
  });

  test('serve omits the install id without personalisation consent', () async {
    final params = <Map<String, String>>[];
    transport_seam.transportClientOverride = () => MockClient((req) async {
          if (req.url.path == '/v1/serve') {
            params.add(Map<String, String>.from(req.url.queryParameters));
            return http.Response(displayFixture, 200);
          }
          return http.Response(featuresFixture(), 200);
        });

    final ad = await AdPluga.initialize(
      publisherKey: 'pk_test_abc',
      telemetryEnabled: false,
    );
    ad.setConsent(const ConsentState(gdpr: true, adPersonalization: false));
    await ad.serve(slotId: 'slot_x');

    expect(params[0].containsKey('u'), isFalse);
  });

  test('serve parses the slot rotation cadence', () async {
    transport_seam.transportClientOverride = () => MockClient((req) async {
          if (req.url.path == '/v1/serve') {
            final body = jsonDecode(displayFixture) as Map<String, Object?>;
            body['refresh_after_seconds'] = 60;
            return http.Response(jsonEncode(body), 200);
          }
          return http.Response(featuresFixture(), 200);
        });

    final ad = await AdPluga.initialize(
      publisherKey: 'pk_test_abc',
      telemetryEnabled: false,
    );
    final resp = await ad.serve(slotId: 'slot_x');
    expect(resp!.refreshAfterSeconds, 60);
  });

  test('serve omits the rotation cadence when the slot has none', () async {
    transport_seam.transportClientOverride = () => MockClient((req) async {
          if (req.url.path == '/v1/serve') {
            return http.Response(displayFixture, 200);
          }
          return http.Response(featuresFixture(), 200);
        });

    final ad = await AdPluga.initialize(
      publisherKey: 'pk_test_abc',
      telemetryEnabled: false,
    );
    final resp = await ad.serve(slotId: 'slot_x');
    expect(resp!.refreshAfterSeconds, 0);
  });

  test('rotation index is sent so refresh impressions stay segregable',
      () async {
    final params = <Map<String, String>>[];
    transport_seam.transportClientOverride = () => MockClient((req) async {
          if (req.url.path == '/v1/serve') {
            params.add(Map<String, String>.from(req.url.queryParameters));
            return http.Response(displayFixture, 200);
          }
          return http.Response(featuresFixture(), 200);
        });

    final ad = await AdPluga.initialize(
      publisherKey: 'pk_test_abc',
      telemetryEnabled: false,
    );
    await ad.serve(slotId: 'slot_x');
    await ad.serve(slotId: 'slot_x', refreshSeq: 2);

    expect(params[0].containsKey('rq'), isFalse);
    expect(params[1]['rq'], '2');
  });

  test('features cache reflects remote flag on ensure', () async {
    var currentFlag = false;
    transport_seam.transportClientOverride = () => MockClient((req) async {
          if (req.url.path == '/v1/features') {
            return http.Response(featuresFixture(telemetry: currentFlag), 200);
          }
          return http.Response('{}', 200);
        });

    final ad = await AdPluga.initialize(
      publisherKey: 'pk_test_abc',
      telemetryEnabled: true,
    );
    await ad.ensureFeatures();
    expect(ad.featuresValue.flag('sdk_telemetry'), isFalse);

    currentFlag = true;
    await ad.ensureFeatures();
    expect(ad.featuresValue.flag('sdk_telemetry'), isTrue);
  });

  test('interstitial accepts html format', () async {
    transport_seam.transportClientOverride = () => MockClient((req) async {
          if (req.url.path == '/v1/serve') {
            return http.Response(htmlFixture, 200);
          }
          if (req.url.path == '/v1/features') {
            return http.Response(featuresFixture(), 200);
          }
          return http.Response('{}', 200);
        });

    await AdPluga.initialize(
      publisherKey: 'pk_test_abc',
      telemetryEnabled: false,
    );

    final ad = await InterstitialAd.load(slotId: 'slot_x');
    expect(ad.response.ad.kind, AdKind.html);
    expect(ad.response.ad.html, isNotNull);
  });

  test('interstitial accepts video format with quartile pings', () async {
    transport_seam.transportClientOverride = () => MockClient((req) async {
          if (req.url.path == '/v1/serve') {
            return http.Response(videoFixture, 200);
          }
          if (req.url.path == '/v1/features') {
            return http.Response(featuresFixture(), 200);
          }
          return http.Response('{}', 200);
        });

    await AdPluga.initialize(
      publisherKey: 'pk_test_abc',
      telemetryEnabled: false,
    );

    final ad = await InterstitialAd.load(slotId: 'slot_v');
    expect(ad.response.ad.kind, AdKind.video);
    expect(ad.response.ad.videoUrl, isNotNull);
    expect(ad.response.ad.durationMs, 15000);
    expect(ad.response.quartilePings, isNotNull);
    expect(ad.response.quartilePings!['complete'], contains('complete'));
  });

  test('rewarded accepts video_rewarded format with skippable window',
      () async {
    transport_seam.transportClientOverride = () => MockClient((req) async {
          if (req.url.path == '/v1/serve') {
            return http.Response(videoRewardedFixture, 200);
          }
          if (req.url.path == '/v1/features') {
            return http.Response(featuresFixture(), 200);
          }
          return http.Response('{}', 200);
        });

    await AdPluga.initialize(
      publisherKey: 'pk_test_abc',
      telemetryEnabled: false,
    );

    final ad = await RewardedAd.load(slotId: 'slot_rw');
    expect(ad.response.ad.kind, AdKind.videoRewarded);
    expect(ad.response.ad.videoUrl, isNotNull);
    expect(ad.response.ad.durationMs, 30000);
    expect(ad.response.ad.skippableAfterMs, 5000);
    expect(ad.response.ad.rewardAmount, 10);
    expect(ad.response.ad.rewardCurrency, 'COIN');
  });

  test('Ad.fromJson parses a carousel deck and drops slides without a creative',
      () {
    final ad = Ad.fromJson(<String, Object?>{
      'id': 'ad-1',
      'type': 'carousel',
      'width': 300,
      'height': 250,
      'slides': <Object?>[
        <String, Object?>{
          'asset_url': 'https://cdn.example/1.png',
          'title': 'Card 1',
          'cta_text': 'Ver',
        },
        <String, Object?>{'asset_url': ''},
        <String, Object?>{'asset_url': 'https://cdn.example/2.png'},
        'not-a-slide',
      ],
    });
    expect(ad.kind, AdKind.carousel);
    expect(ad.slides.length, 2);
    expect(ad.slides.first.title, 'Card 1');
    expect(ad.slides.first.ctaText, 'Ver');
    expect(ad.slides.last.assetUrl, 'https://cdn.example/2.png');
  });

  test('Ad.fromJson leaves slides empty for every other creative type', () {
    final ad = Ad.fromJson(<String, Object?>{
      'id': 'ad-2',
      'type': 'image',
      'asset_url': 'https://cdn.example/banner.png',
    });
    expect(ad.slides, isEmpty);
  });

  testWidgets('AdPlugaCarousel reports one tap per card, never a new serve',
      (tester) async {
    var clicks = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 300,
          height: 250,
          child: AdPlugaCarousel(
            slides: const <Slide>[
              Slide(assetUrl: 'https://cdn.example/1.png', title: 'Card 1'),
              Slide(assetUrl: 'https://cdn.example/2.png'),
            ],
            onClick: () => clicks += 1,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(PageView));
    expect(clicks, 1);
  });

  testWidgets('AdPlugaCarousel signals interaction when the deck is swiped',
      (tester) async {
    var interactions = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 300,
          height: 250,
          child: AdPlugaCarousel(
            slides: const <Slide>[
              Slide(assetUrl: 'https://cdn.example/1.png'),
              Slide(assetUrl: 'https://cdn.example/2.png'),
            ],
            onClick: () {},
            onInteraction: () => interactions += 1,
          ),
        ),
      ),
    );
    await tester.timedDrag(
      find.byType(PageView),
      const Offset(-280, 0),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();
    expect(interactions, 1);
  });

  test('a path-only impression url is dialled against the endpoint', () async {
    final beaconPaths = <String>[];
    final beaconHosts = <String>[];
    transport_seam.transportClientOverride = () => MockClient((req) async {
          if (req.url.path == '/v1/serve') {
            return http.Response(relativeTrackingFixture, 200);
          }
          if (req.url.path == '/v1/features') {
            return http.Response(featuresFixture(), 200);
          }
          if (req.method == 'GET' &&
              (req.url.path == '/v1/imp' || req.url.path == '/v1/click')) {
            beaconPaths.add(req.url.path);
            beaconHosts.add(req.url.host);
            return http.Response('', 200);
          }
          return http.Response('{}', 200);
        });

    final ad = await AdPluga.initialize(
      publisherKey: 'pk_test_abc',
      telemetryEnabled: false,
    );
    final resp = await ad.serve(slotId: 'slot_x');
    expect(resp, isNotNull);
    ad.fireImpression(resp!, 'slot_x');
    ad.fireClick(resp, 'slot_x');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(beaconPaths, containsAll(<String>['/v1/imp', '/v1/click']));
    for (final host in beaconHosts) {
      expect(host, isNotEmpty,
          reason: 'a relative beacon never leaves the device');
    }
  });

  test('conversion posts the wire field names, not the SDK argument names',
      () async {
    final bodies = <String>[];
    transport_seam.transportClientOverride = () => MockClient((req) async {
          if (req.url.path == '/v1/features') {
            return http.Response(featuresFixture(), 200);
          }
          if (req.url.path == '/v1/track') {
            bodies.add(req.body);
            return http.Response('', 204);
          }
          return http.Response('{}', 200);
        });

    final ad = await AdPluga.initialize(
      publisherKey: 'pk_test_abc',
      telemetryEnabled: false,
    );
    await ad.conversion(token: 'tok', convType: 'purchase', valueCents: 1250);

    expect(bodies, hasLength(1));
    final body = jsonDecode(bodies.first) as Map<String, Object?>;
    // event, not kind: the API defaults a missing event to impression, which
    // would bill a conversion as an impression.
    expect(body['event'], 'conversion');
    expect(body['conv_type'], 'purchase');
    expect(body['value_cents'], 1250);
  });

  test('re-initializing with a different key throws instead of no-op',
      () async {
    transport_seam.transportClientOverride = () => MockClient((req) async {
          if (req.url.path == '/v1/features') {
            return http.Response(featuresFixture(), 200);
          }
          return http.Response('{}', 200);
        });

    final first = await AdPluga.initialize(
      publisherKey: 'pk_test_aaaaaaaa',
      telemetryEnabled: false,
    );

    // Rotating a key revokes the previous one, so silently returning the old
    // instance would leave the app serving with a dead key.
    await expectLater(
      AdPluga.initialize(
        publisherKey: 'pk_test_bbbbbbbb',
        telemetryEnabled: false,
      ),
      throwsA(isA<AlreadyInitializedError>()),
    );

    // Same key stays idempotent.
    final again = await AdPluga.initialize(
      publisherKey: 'pk_test_aaaaaaaa',
      telemetryEnabled: false,
    );
    expect(again, same(first));
  });

  test('a null endpoint falls back to the exported default', () async {
    transport_seam.transportClientOverride = () => MockClient((req) async {
          if (req.url.path == '/v1/features') {
            return http.Response(featuresFixture(), 200);
          }
          return http.Response('{}', 200);
        });

    final ad = await AdPluga.initialize(
      publisherKey: 'pk_test_abc',
      endpoint: null,
      telemetryEnabled: false,
    );
    expect(ad.config.endpoint, kDefaultEndpoint);
  });

  testWidgets('a no-fill slot keeps trying instead of dying for the session',
      (tester) async {
    var serves = 0;
    transport_seam.transportClientOverride = () => MockClient((req) async {
          if (req.url.path == '/v1/features') {
            return http.Response(featuresFixture(), 200);
          }
          if (req.url.path == '/v1/serve') {
            serves += 1;
            // First attempt misses; the slot must come back on its own.
            if (serves == 1) return http.Response('', 204);
            return http.Response(displayFixture, 200);
          }
          return http.Response('{}', 200);
        });

    await AdPluga.initialize(
      publisherKey: 'pk_test_abc',
      telemetryEnabled: false,
    );
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 320,
          height: 100,
          child: AdPlugaBanner(slotId: 'slot_x'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(serves, 1, reason: 'the first attempt missed');

    // pk_test_ floor is 15s, so the first retry lands there.
    await tester.pump(const Duration(seconds: 16));
    await tester.pump(const Duration(milliseconds: 50));
    expect(serves, 2, reason: 'a missed fill must schedule another attempt');

    // testWidgets asserts on pending timers before tearDown runs, and the
    // features cache keeps a periodic one.
    await tester.pumpWidget(const SizedBox.shrink());
    await AdPluga.maybeInstance?.destroy();
  });
}
