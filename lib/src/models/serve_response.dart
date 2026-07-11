import 'package:meta/meta.dart';

enum AdKind { image, html, native, template, video, videoRewarded, unknown }

AdKind adKindFromString(String value) {
  switch (value) {
    case 'image':
      return AdKind.image;
    case 'html':
      return AdKind.html;
    case 'native':
      return AdKind.native;
    case 'template':
      return AdKind.template;
    case 'video':
      return AdKind.video;
    case 'video_rewarded':
      return AdKind.videoRewarded;
    default:
      return AdKind.unknown;
  }
}

enum AdSource { pool, direto, house, deal, mediation, test, unknown }

AdSource adSourceFromString(String value) {
  switch (value) {
    case 'pool':
      return AdSource.pool;
    case 'direto':
      return AdSource.direto;
    case 'house':
      return AdSource.house;
    case 'deal':
      return AdSource.deal;
    case 'mediation':
      return AdSource.mediation;
    case 'test':
      return AdSource.test;
    default:
      return AdSource.unknown;
  }
}

@immutable
class Ad {
  const Ad({
    required this.id,
    required this.kind,
    this.assetUrl,
    this.html,
    this.clickUrl,
    this.width = 0,
    this.height = 0,
    this.title,
    this.body,
    this.ctaText,
    this.sponsoredBy,
    this.iconUrl,
    this.mainImageUrl,
    this.videoUrl,
    this.durationMs = 0,
    this.skippableAfterMs = 0,
    this.rewardAmount = 0,
    this.rewardCurrency,
  });

  final String id;
  final AdKind kind;
  final String? assetUrl;
  final String? html;
  final String? clickUrl;
  final int width;
  final int height;
  final String? title;
  final String? body;
  final String? ctaText;
  final String? sponsoredBy;
  final String? iconUrl;
  final String? mainImageUrl;
  final String? videoUrl;
  final int durationMs;
  final int skippableAfterMs;
  final int rewardAmount;
  final String? rewardCurrency;

  factory Ad.fromJson(Map<String, Object?> json) {
    return Ad(
      id: (json['id'] as String?) ?? '',
      kind: adKindFromString((json['type'] as String?) ?? ''),
      assetUrl: json['asset_url'] as String?,
      html: json['html'] as String?,
      clickUrl: json['click_url'] as String?,
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      title: json['title'] as String?,
      body: json['body'] as String?,
      ctaText: json['cta_text'] as String?,
      sponsoredBy: json['sponsored_by'] as String?,
      iconUrl: json['icon_url'] as String?,
      mainImageUrl: json['main_image_url'] as String?,
      videoUrl: json['video_url'] as String?,
      durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
      skippableAfterMs: (json['skippable_after_ms'] as num?)?.toInt() ?? 0,
      rewardAmount: (json['reward_amount'] as num?)?.toInt() ?? 0,
      rewardCurrency: json['reward_currency'] as String?,
    );
  }
}

@immutable
class ServeResponse {
  const ServeResponse({
    required this.ad,
    required this.trackToken,
    required this.source,
    this.impressionUrl,
    this.clickUrl,
    this.conversionUrl,
    this.conversionToken,
    this.quartilePings,
  });

  final Ad ad;
  final String trackToken;
  final AdSource source;
  final String? impressionUrl;
  final String? clickUrl;
  final String? conversionUrl;
  final String? conversionToken;
  final Map<String, String>? quartilePings;

  factory ServeResponse.fromJson(Map<String, Object?> json) {
    final adJson = (json['ad'] as Map?)?.cast<String, Object?>() ?? const {};
    final pings = json['quartile_pings'];
    return ServeResponse(
      ad: Ad.fromJson(adJson),
      trackToken: (json['track_token'] as String?) ?? '',
      source: adSourceFromString((json['source'] as String?) ?? ''),
      impressionUrl: json['impression_url'] as String?,
      clickUrl: json['click_url'] as String?,
      conversionUrl: json['conversion_url'] as String?,
      conversionToken: json['conversion_token'] as String?,
      quartilePings: pings is Map
          ? pings.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))
          : null,
    );
  }
}
