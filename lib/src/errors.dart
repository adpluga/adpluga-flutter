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
