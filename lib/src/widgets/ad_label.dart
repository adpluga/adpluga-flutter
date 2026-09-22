import '../models/serve_response.dart';

/// Label announced by a screen reader in place of the creative. An ad is never
/// decorative — it carries meaning and opens a destination — so an unlabelled
/// image leaves the tap target with no name at all (WCAG 2.2 SC 1.1.1 and
/// SC 2.4.4, both level A). Falls back to the title, then to a neutral word,
/// which is still a name.
String adLabel(Ad ad) {
  final alt = ad.altText;
  if (alt != null && alt.isNotEmpty) return alt;
  final title = ad.title;
  if (title != null && title.isNotEmpty) return title;
  return 'Anuncio';
}

/// Slides share the ad's destination, so a slide with no copy of its own
/// inherits the ad's label rather than going unnamed.
String slideLabel(Ad ad, Slide slide) {
  final title = slide.title;
  if (title != null && title.isNotEmpty) return title;
  return adLabel(ad);
}
