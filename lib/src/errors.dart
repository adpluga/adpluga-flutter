sealed class AdPlugaError implements Exception {
  const AdPlugaError(this.message);
  final String message;

  @override
  String toString() => 'AdPlugaError($message)';
}

class NotInitializedError extends AdPlugaError {
  const NotInitializedError()
      : super('AdPluga.initialize must be called before use');
}

class InvalidKeyError extends AdPlugaError {
  const InvalidKeyError(super.message);
}

/// Thrown when [AdPluga.initialize] is called with a different publisher key
/// than the live instance was built with. Rotating a key revokes the previous
/// one immediately, so returning the old instance would leave the app serving
/// with a revoked key and nothing to signal it. Call `destroy()` first to
/// re-initialize deliberately.
class AlreadyInitializedError extends AdPlugaError {
  const AlreadyInitializedError(this.activeKeyPrefix, this.requestedKeyPrefix)
      : super('AdPluga is already initialized with a different publisher key; '
            'call destroy() before initializing again');

  final String activeKeyPrefix;
  final String requestedKeyPrefix;
}

class NetworkError extends AdPlugaError {
  const NetworkError(super.message, {this.statusCode});
  final int? statusCode;
}

class UpgradeRequiredError extends AdPlugaError {
  const UpgradeRequiredError(this.minVersion) : super('SDK upgrade required');
  final String minVersion;
}

class ConsentDeniedError extends AdPlugaError {
  const ConsentDeniedError() : super('consent_required');
}

class UnsupportedFormatError extends AdPlugaError {
  const UnsupportedFormatError(String kind)
      : super('unsupported ad type: $kind');
}
