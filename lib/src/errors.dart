/// Base class of every error the SDK throws or passes to an error handler.
sealed class AdPlugaError implements Exception {
  /// Creates an error with [message].
  const AdPlugaError(this.message);

  /// Human-readable description of the failure.
  final String message;

  @override
  String toString() => 'AdPlugaError($message)';
}

/// Thrown when the SDK is used before `AdPluga.initialize` has completed.
class NotInitializedError extends AdPlugaError {
  /// Creates the error with a fixed message.
  const NotInitializedError()
      : super('AdPluga.initialize must be called before use');
}

/// Thrown by `AdPluga.initialize` when the publisher key does not start with
/// `pk_live_` or `pk_test_`.
class InvalidKeyError extends AdPlugaError {
  /// Creates the error with [message].
  const InvalidKeyError(super.message);
}

/// Thrown when [AdPluga.initialize] is called with a different publisher key
/// than the live instance was built with. Rotating a key revokes the previous
/// one immediately, so returning the old instance would leave the app serving
/// with a revoked key and nothing to signal it. Call `destroy()` first to
/// re-initialize deliberately.
class AlreadyInitializedError extends AdPlugaError {
  /// Creates the error for the active and the requested key.
  const AlreadyInitializedError(this.activeKeyPrefix, this.requestedKeyPrefix)
      : super('AdPluga is already initialized with a different publisher key; '
            'call destroy() before initializing again');

  /// Key the live instance was initialized with.
  final String activeKeyPrefix;

  /// Key passed to the rejected call.
  final String requestedKeyPrefix;
}

/// A request to the AdPluga API failed, timed out or returned an unusable
/// body. Also used with the message `no fill` when a slot gets no ad.
class NetworkError extends AdPlugaError {
  /// Creates the error with [message] and an optional HTTP [statusCode].
  const NetworkError(super.message, {this.statusCode});

  /// HTTP status of the failed response, when one was received.
  final int? statusCode;
}

/// The server answered HTTP 426: this SDK version is no longer accepted.
class UpgradeRequiredError extends AdPlugaError {
  /// Creates the error for the required [minVersion].
  const UpgradeRequiredError(this.minVersion) : super('SDK upgrade required');

  /// Minimum SDK version from the server's response header, or an empty
  /// string if absent.
  final String minVersion;
}

/// Signals that consent is required. Not currently thrown by the SDK.
class ConsentDeniedError extends AdPlugaError {
  /// Creates the error with the message `consent_required`.
  const ConsentDeniedError() : super('consent_required');
}

/// Thrown when a full-screen format receives an ad kind it cannot render.
class UnsupportedFormatError extends AdPlugaError {
  /// Creates the error for the unsupported ad [kind].
  const UnsupportedFormatError(String kind)
      : super('unsupported ad type: $kind');
}
