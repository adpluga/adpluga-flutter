import 'dart:convert';

import 'package:adpluga_flutter/adpluga_flutter.dart';
import 'package:adpluga_flutter/src/client/transport.dart' as transport_seam;
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

  test('rewarded accepts video_rewarded format with skippable window', () async {
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
}
