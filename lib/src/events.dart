import 'package:meta/meta.dart';

import 'consent.dart';
import 'models/features.dart';
import 'models/serve_response.dart';

/// Base class of the events published on `AdPluga.events`.
sealed class SdkEvent {
  /// Base constructor for subclasses.
  const SdkEvent();
}

@immutable

/// Emitted when `AdPluga.initialize` has created the instance.
class InitCompletedEvent extends SdkEvent {
  /// Creates the event.
  const InitCompletedEvent();
}

@immutable

/// Emitted when a serve request for a slot returns an ad.
class AdServedEvent extends SdkEvent {
  /// Creates the event for [slotId] and its [response].
  const AdServedEvent({required this.slotId, required this.response});

  /// Slot the ad was requested for.
  final String slotId;

  /// Ad returned by the server.
  final ServeResponse response;
}

@immutable

/// Emitted when a serve request for a slot fails.
class AdFailedEvent extends SdkEvent {
  /// Creates the event for [slotId] with the error [message].
  const AdFailedEvent({required this.slotId, required this.message});

  /// Slot the ad was requested for.
  final String slotId;

  /// Message of the [AdPlugaError] that caused the failure.
  final String message;
}

@immutable

/// Emitted when an impression is reported.
class ImpressionEvent extends SdkEvent {
  /// Creates the event for [slotId] and the ad's [source].
  const ImpressionEvent({required this.slotId, required this.source});

  /// Slot that showed the ad.
  final String slotId;

  /// Demand source of the ad.
  final AdSource source;
}

@immutable

/// Emitted when a click is reported.
class ClickEvent extends SdkEvent {
  /// Creates the event for [slotId] and the ad's [source].
  const ClickEvent({required this.slotId, required this.source});

  /// Slot that showed the ad.
  final String slotId;

  /// Demand source of the ad.
  final AdSource source;
}

@immutable

/// Emitted when `AdPluga.setConsent` is called.
class ConsentChangedEvent extends SdkEvent {
  /// Creates the event with the new [state].
  const ConsentChangedEvent(this.state);

  /// Consent state now in effect.
  final ConsentState state;
}

@immutable

/// Emitted each time a features fetch returns a new payload (not a 304).
class FeaturesUpdatedEvent extends SdkEvent {
  /// Creates the event with the fetched [features].
  const FeaturesUpdatedEvent(this.features);

  /// Features now in effect.
  final FeaturesView features;
}

@immutable

/// Emitted when the server rejects this SDK version. Later serve calls return
/// null without a request.
class UpgradeRequiredSdkEvent extends SdkEvent {
  /// Creates the event with the required [minVersion].
  const UpgradeRequiredSdkEvent({required this.minVersion});

  /// Minimum SDK version demanded by the server.
  final String minVersion;
}
