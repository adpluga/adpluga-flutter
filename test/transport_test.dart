import 'package:adpluga_flutter/adpluga_flutter.dart';
import 'package:adpluga_flutter/src/client/transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/fixtures.dart';

const _ua = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36';

void main() {
  late List<http.BaseRequest> sent;

  Transport transport({UserAgentSource? ua}) => Transport(
        endpoint: 'https://edge.adpluga.test',
        publisherKey: 'pk_test_abcdefghij',
        userAgentSource: ua ?? () async => _ua,
        clientFactory: () => MockClient((req) async {
          sent.add(req);
          if (req.url.path == '/v1/serve') {
            return http.Response(displayFixture, 200);
          }
          return http.Response('', 204);
        }),
      );

  setUp(() => sent = <http.BaseRequest>[]);

  test('serve sends the device user agent', () async {
    await transport().serve(slotId: 'slot_1');
    expect(sent.single.headers['X-Device-User-Agent'], _ua);
  });

  test('a failing user agent lookup omits the header and still serves',
      () async {
    await transport(ua: () async => throw StateError('no webview'))
        .serve(slotId: 'slot_1');
    expect(sent.single.headers.containsKey('X-Device-User-Agent'), isFalse);
  });

  test('third-party pixel gets the device UA and never the publisher key',
      () async {
    await transport().beacon('https://ssp.example/imp?p=1');
    final headers = sent.single.headers;
    expect(headers['User-Agent'], _ua);
    expect(headers.containsKey('X-AdPluga-Key'), isFalse);
  });

  test('mediation trackers are parsed and default to empty', () {
    final ad = Ad.fromJson(const {
      'id': 'm',
      'type': 'video',
      'impression_trackers': ['https://ssp/imp', 3],
      'click_trackers': ['https://ssp/clk'],
    });
    expect(ad.impressionTrackers, ['https://ssp/imp']);
    expect(ad.clickTrackers, ['https://ssp/clk']);
    final plain = Ad.fromJson(const {'id': 'h', 'type': 'image'});
    expect(plain.impressionTrackers, isEmpty);
    expect(plain.clickTrackers, isEmpty);
  });
}
