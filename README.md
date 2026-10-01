# AdPluga Flutter SDK

Ad serving, viewability tracking, and mediation client for Flutter apps.
Talks to the AdPluga edge (`/v1/serve` + `/v1/track`) and renders banner,
native, interstitial, rewarded, HTML5, and video formats.

- **Package**: [`adpluga_flutter`](https://pub.dev/packages/adpluga_flutter) on pub.dev
- **Platforms**: Android, iOS, Web
- **Dart**: `>=3.0.0 <4.0.0` · **Flutter**: `>=3.10.0`
- **License**: Apache-2.0 — see [LICENSE](./LICENSE)

## Why AdPluga

- **100,000 ad decisions free every month.** No card, no expiry.
- **No traffic minimum.** When there is no demand, a house ad fills the slot so it never renders empty.
- **Test mode first.** A `pk_test_` key serves ads with no billing and no quota use; switch to `pk_live_` when you are ready.
- **One integration, every demand source.** Direct deals, network demand and mediation behind the same slot.

Create a free account at <https://adpluga.com/en/> and get your keys in the dashboard.

## Install

```yaml
dependencies:
  adpluga_flutter: ^0.7.2
```

```bash
flutter pub add adpluga_flutter
```

## Quick start

```dart
import 'package:adpluga_flutter/adpluga_flutter.dart';

await AdPluga.initialize(
  publisherKey: 'pk_test_...',
);

AdPlugaBanner(
  slotId: 'slot_home_320x100',
  onImpression: () {},
  onClick: () {},
  onError: (err) {},
);
```

Integration guides and API reference: <https://adpluga.com/en/devs/sdks/> · quick start in two minutes: <https://adpluga.com/en/devs/quickstart/>.

## Support

- Issues and questions: <https://github.com/adpluga/adpluga-flutter/issues>
- Security disclosures: <security@adpluga.com>

This repository is a read-only mirror of the internal monorepo. Pull requests
are accepted for discussion but changes are integrated upstream.
