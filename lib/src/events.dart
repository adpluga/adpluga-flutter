import 'package:meta/meta.dart';

import 'consent.dart';
import 'models/features.dart';
import 'models/serve_response.dart';

sealed class SdkEvent {
  const SdkEvent();
}

@immutable
class InitCompletedEvent extends SdkEvent {
  const InitCompletedEvent();
}

@immutable
class AdServedEvent extends SdkEvent {
  const AdServedEvent({required this.slotId, required this.response});
  final String slotId;
  final ServeResponse response;
}

@immutable
class AdFailedEvent extends SdkEvent {
  const AdFailedEvent({required this.slotId, required this.message});
  final String slotId;
  final String message;
}

@immutable
class ImpressionEvent extends SdkEvent {
  const ImpressionEvent({required this.slotId, required this.source});
  final String slotId;
  final AdSource source;
}

@immutable
class ClickEvent extends SdkEvent {
  const ClickEvent({required this.slotId, required this.source});
  final String slotId;
  final AdSource source;
}

@immutable
class ConsentChangedEvent extends SdkEvent {
  const ConsentChangedEvent(this.state);
  final ConsentState state;
}

@immutable
class FeaturesUpdatedEvent extends SdkEvent {
  const FeaturesUpdatedEvent(this.features);
  final FeaturesView features;
}

@immutable
class UpgradeRequiredSdkEvent extends SdkEvent {
  const UpgradeRequiredSdkEvent({required this.minVersion});
  final String minVersion;
}
