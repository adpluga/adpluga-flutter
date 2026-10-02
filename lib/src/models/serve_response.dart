import 'package:meta/meta.dart';

/// Creative type of an [Ad], parsed from the `type` field of the serve
/// response.
enum AdKind {
  /// A static image at [Ad.assetUrl].
  image,

  /// HTML markup in [Ad.html], or a page at [Ad.assetUrl].
  html,

  /// Native assets (title, body, images) laid out by the host app.
  native,

  /// Rendered like [image].
  template,

  /// A video at [Ad.videoUrl].
  video,

  /// A video that grants a reward when watched; wire value `video_rewarded`.
  videoRewarded,

  /// An audio creative, played through the video player.
  audio,

  /// A deck of [Ad.slides].
  carousel,

  /// Any type this SDK version does not recognise.
  unknown
}

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
    case 'audio':
      return AdKind.audio;
    case 'carousel':
      return AdKind.carousel;
    default:
      return AdKind.unknown;
  }
}

/// Demand source that filled the slot, parsed from the `source` field of the
/// serve response.
enum AdSource {
  /// The shared advertiser pool.
  pool,

  /// A direct deal between the publisher and an advertiser.
  direto,

  /// The platform's house creatives.
  house,

  /// Wire value `deal`.
  deal,

  /// A third-party network reached through mediation.
  mediation,

  /// A network AdPluga sells to on the publisher's behalf; paid demand.
  platformMediation,

  /// A sandbox creative.
  test,

  /// Any source this SDK version does not recognise.
  unknown
}

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
    case 'platform_mediation':
      return AdSource.platformMediation;
    case 'test':
      return AdSource.test;
    default:
      return AdSource.unknown;
  }
}

/// One card of a carousel. The whole deck shares the ad's click token and its
/// single impression, so swiping never mints or spends anything extra.
@immutable
class Slide {
  /// Creates a slide.
  const Slide({
    required this.assetUrl,
    this.title,
    this.body,
    this.ctaText,
  });

  /// Image shown on the card.
  final String assetUrl;

  /// Headline; also used as the card's semantic label when present.
  final String? title;

  /// Body copy.
  final String? body;

  /// Call-to-action label.
  final String? ctaText;

  /// Parses one entry of the `slides` array. A missing `asset_url` becomes
  /// an empty string.
  factory Slide.fromJson(Map<String, Object?> json) {
    return Slide(
      assetUrl: (json['asset_url'] as String?) ?? '',
      title: json['title'] as String?,
      body: json['body'] as String?,
      ctaText: json['cta_text'] as String?,
    );
  }
}

List<Slide> _slidesFromJson(Object? raw) {
  if (raw is! List) return const <Slide>[];
  final out = <Slide>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final slide = Slide.fromJson(Map<String, Object?>.from(item));
    if (slide.assetUrl.isNotEmpty) out.add(slide);
  }
  return out;
}

/// The creative returned by a serve request.
///
/// Which fields are set depends on [kind]; absent numeric fields are 0.
@immutable
class Ad {
  /// Creates an ad.
  const Ad({
    required this.id,
    required this.kind,
    this.assetUrl,
    this.html,
    this.billingUrl,
    this.clickUrl,
    this.width = 0,
    this.height = 0,
    this.title,
    this.altText,
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
    this.slides = const <Slide>[],
    this.isTest = false,
    this.impressionTrackers = const <String>[],
    this.clickTrackers = const <String>[],
  });

  /// Ad identifier.
  final String id;

  /// Creative type.
  final AdKind kind;

  /// URL of the main asset: the image, or the HTML page when [html] is empty.
  final String? assetUrl;

  /// Inline HTML markup for [AdKind.html] creatives.
  final String? html;

  /// URL fired once when the ad becomes viewable, set on mediation fills.
  final String? billingUrl;

  /// Advertiser destination opened on tap.
  final String? clickUrl;

  /// Creative width in pixels, or 0 if unknown.
  final int width;

  /// Creative height in pixels, or 0 if unknown.
  final int height;

  /// Headline.
  final String? title;

  /// Read aloud in place of the creative. An ad is never decorative, so a
  /// renderer with nothing here falls back to the title rather than leaving
  /// the image unlabelled.
  final String? altText;

  /// Body copy.
  final String? body;

  /// Call-to-action label.
  final String? ctaText;

  /// Advertiser name; the banner announces it as "Sponsored by ...".
  final String? sponsoredBy;

  /// Icon image URL for native layouts.
  final String? iconUrl;

  /// Main image URL for native layouts; also the fallback image when
  /// [assetUrl] is absent.
  final String? mainImageUrl;

  /// Video URL for video and audio creatives.
  final String? videoUrl;

  /// Creative duration in milliseconds.
  final int durationMs;

  /// Playback position, in milliseconds, after which a rewarded video may be
  /// closed; 0 means it cannot be skipped.
  final int skippableAfterMs;

  /// Reward granted by a rewarded ad.
  final int rewardAmount;

  /// Currency or unit of [rewardAmount]. `RewardedAd` reports `USD` when
  /// absent.
  final String? rewardCurrency;

  /// Carousel cards; empty for other kinds.
  final List<Slide> slides;

  /// Whether this is a sandbox creative. Test creatives are drawn with a
  /// `TEST` badge.
  final bool isTest;

  /// A mediation bidder's own impression pixels, fired with ours so the SSP
  /// counts (and pays for) what it served. Empty for first-party creatives.
  final List<String> impressionTrackers;

  /// A mediation bidder's own click pixels, fired with ours.
  final List<String> clickTrackers;

  /// Parses the `ad` object of a serve response. Slides without an
  /// `asset_url` are dropped.
  factory Ad.fromJson(Map<String, Object?> json) {
    return Ad(
      id: (json['id'] as String?) ?? '',
      kind: adKindFromString((json['type'] as String?) ?? ''),
      assetUrl: json['asset_url'] as String?,
      html: json['html'] as String?,
      billingUrl: json['billing_url'] as String?,
      clickUrl: json['click_url'] as String?,
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      title: json['title'] as String?,
      altText: json['alt_text'] as String?,
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
      slides: _slidesFromJson(json['slides']),
      isTest: (json['test'] as bool?) ?? false,
      impressionTrackers: _stringList(json['impression_trackers']),
      clickTrackers: _stringList(json['click_trackers']),
    );
  }
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const <String>[];
  return List<String>.unmodifiable(raw.whereType<String>());
}

/// Result of a successful serve request: the ad plus the URLs and tokens
/// used to report its events.
@immutable
class ServeResponse {
  /// Creates a serve response.
  const ServeResponse({
    required this.ad,
    required this.trackToken,
    required this.source,
    this.impressionUrl,
    this.clickUrl,
    this.conversionUrl,
    this.conversionToken,
    this.quartilePings,
    this.refreshAfterSeconds = 0,
  });

  /// The creative to render.
  final Ad ad;

  /// Signed token used to report the impression and viewability. Empty on
  /// fills that carry none, such as mediation.
  final String trackToken;

  /// Demand source that filled the slot.
  final AdSource source;

  /// Impression beacon URL; when absent the impression is reported with
  /// [trackToken].
  final String? impressionUrl;

  /// Click beacon URL. Clicks are only reported when it is present.
  final String? clickUrl;

  /// Conversion URL from the `conversion_url` field.
  final String? conversionUrl;

  /// Conversion token from the `conversion_token` field.
  final String? conversionToken;

  /// Video progress beacon URLs keyed by `start`, `first_quartile`,
  /// `midpoint`, `third_quartile` and `complete`.
  final Map<String, String>? quartilePings;

  /// Publisher-configured rotation cadence for this slot, in seconds.
  /// 0 means the slot must not rotate.
  final int refreshAfterSeconds;

  /// Parses a `/v1/serve` response body.
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
      refreshAfterSeconds:
          (json['refresh_after_seconds'] as num?)?.toInt() ?? 0,
    );
  }
}
