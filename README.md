# AdPluga Flutter SDK

Ad serving, viewability tracking, and mediation client for Flutter apps.
Talks to the AdPluga edge (`/v1/serve` + `/v1/track`) and renders banner,
native, interstitial, rewarded, HTML5, and video formats.

- **Package**: [`adpluga_flutter`](https://pub.dev/packages/adpluga_flutter) on pub.dev
- **Platforms**: Android, iOS, Web
- **Dart**: `>=3.0.0 <4.0.0` · **Flutter**: `>=3.10.0`
- **License**: Proprietary — see [LICENSE](./LICENSE)

## Install

```yaml
dependencies:
  adpluga_flutter: ^0.2.0
```

```bash
flutter pub add adpluga_flutter
```

## Quick start

```dart
import 'package:adpluga_flutter/adpluga_flutter.dart';

await AdPluga.initialize(
  publisherKey: 'pk_live_...',
);

AdPlugaBanner(
  slotId: 'slot_home_320x100',
  onImpression: () {},
  onClick: () {},
  onError: (err) {},
);
```

Full API reference and integration guides: <https://app.adpluga.com/docs/sdk/flutter>.

## Support

- Issues and questions: <https://github.com/adpluga/adpluga-flutter/issues>
- Security disclosures: <security@adpluga.com>

This repository is a read-only mirror of the internal monorepo. Pull requests
are accepted for discussion but changes are integrated upstream.
