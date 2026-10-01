import 'package:meta/meta.dart';

/// Remote feature flags fetched from the API's `/v1/features` endpoint.
@immutable
class FeaturesView {
  /// Creates a view from already-parsed maps.
  const FeaturesView({required this.flags, required this.sdkMinVersion});

  /// Boolean flags by name.
  final Map<String, bool> flags;

  /// Minimum SDK version by key, as sent in `sdk_min_version`.
  final Map<String, String> sdkMinVersion;

  /// Returns the flag named [key], or [fallback] when it is absent.
  bool flag(String key, {bool fallback = false}) => flags[key] ?? fallback;

  /// Parses the features payload. A flag is true only when its JSON value
  /// is `true`; missing maps become empty.
  factory FeaturesView.fromJson(Map<String, Object?> json) {
    final rawFlags =
        (json['flags'] as Map?)?.cast<Object?, Object?>() ?? const {};
    final rawMin =
        (json['sdk_min_version'] as Map?)?.cast<Object?, Object?>() ?? const {};
    return FeaturesView(
      flags: <String, bool>{
        for (final e in rawFlags.entries)
          if (e.key != null) e.key.toString(): e.value == true,
      },
      sdkMinVersion: <String, String>{
        for (final e in rawMin.entries)
          if (e.key != null) e.key.toString(): e.value?.toString() ?? '',
      },
    );
  }

  /// A view with no flags, used before the first successful fetch.
  static const FeaturesView empty = FeaturesView(
    flags: <String, bool>{},
    sdkMinVersion: <String, String>{},
  );
}
