import 'package:meta/meta.dart';

@immutable
class FeaturesView {
  const FeaturesView({required this.flags, required this.sdkMinVersion});

  final Map<String, bool> flags;
  final Map<String, String> sdkMinVersion;

  bool flag(String key, {bool fallback = false}) => flags[key] ?? fallback;

  factory FeaturesView.fromJson(Map<String, Object?> json) {
    final rawFlags = (json['flags'] as Map?)?.cast<Object?, Object?>() ?? const {};
    final rawMin = (json['sdk_min_version'] as Map?)?.cast<Object?, Object?>() ?? const {};
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

  static const FeaturesView empty = FeaturesView(
    flags: <String, bool>{},
    sdkMinVersion: <String, String>{},
  );
}
