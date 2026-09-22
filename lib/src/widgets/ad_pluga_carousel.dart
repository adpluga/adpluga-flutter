import 'package:flutter/widgets.dart';

import '../models/serve_response.dart';
import 'test_badge.dart';

const Color _kCaptionBackground = Color(0xD1111827);
const Color _kCaptionForeground = Color(0xFFFFFFFF);
const Color _kCtaBackground = Color(0xFFFFFFFF);
const Color _kCtaForeground = Color(0xFF111827);
const Color _kIndicatorActive = Color(0xFFFFFFFF);
const Color _kIndicatorIdle = Color(0x66FFFFFF);

/// Renders a carousel deck as a horizontal [PageView]. The deck is one
/// advertiser and one auction, so every card reports the same tap and the
/// widget never asks for another creative — swiping is presentation only.
///
/// [onInteraction] fires on every swipe so the host can hold off a scheduled
/// rotation: replacing the deck under the user's finger would lose their place.
class AdPlugaCarousel extends StatefulWidget {
  const AdPlugaCarousel({
    super.key,
    required this.slides,
    required this.onClick,
    this.fallbackLabel = 'Anuncio',
    this.onInteraction,
    this.isTest = false,
  });

  final List<Slide> slides;

  /// Announced for a slide that carries no copy of its own. The deck shares one
  /// destination, so an unnamed card would be an unnamed link.
  final String fallbackLabel;
  final VoidCallback onClick;
  final VoidCallback? onInteraction;
  final bool isTest;

  @override
  State<AdPlugaCarousel> createState() => _AdPlugaCarouselState();
}

class _AdPlugaCarouselState extends State<AdPlugaCarousel> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _page = page);
    widget.onInteraction?.call();
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    if (slides.isEmpty) return const SizedBox.shrink();

    final deck = PageView.builder(
      controller: _controller,
      itemCount: slides.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, i) => _SlideCard(
        slide: slides[i],
        fallbackLabel: widget.fallbackLabel,
        onTap: widget.onClick,
      ),
    );

    return withTestBadge(
      Stack(
        children: [
          Positioned.fill(child: deck),
          if (slides.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 6,
              child: _PageDots(count: slides.length, active: _page),
            ),
        ],
      ),
      isTest: widget.isTest,
    );
  }
}

class _SlideCard extends StatelessWidget {
  const _SlideCard({
    required this.slide,
    required this.fallbackLabel,
    required this.onTap,
  });

  final Slide slide;
  final String fallbackLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasCopy = (slide.title?.isNotEmpty ?? false) ||
        (slide.body?.isNotEmpty ?? false) ||
        (slide.ctaText?.isNotEmpty ?? false);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              slide.assetUrl,
              fit: BoxFit.cover,
              semanticLabel:
                  slide.title?.isNotEmpty == true ? slide.title : fallbackLabel,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          if (hasCopy)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _Caption(slide: slide),
            ),
        ],
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({required this.slide});

  final Slide slide;

  @override
  Widget build(BuildContext context) {
    final title = slide.title;
    final body = slide.body;
    final cta = slide.ctaText;
    return DecoratedBox(
      decoration: const BoxDecoration(color: _kCaptionBackground),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null && title.isNotEmpty)
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  color: _kCaptionForeground,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            if (body != null && body.isNotEmpty)
              Text(
                body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  color: _kCaptionForeground,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            if (cta != null && cta.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: _kCtaBackground,
                    borderRadius: BorderRadius.all(Radius.circular(3)),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      cta,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        color: _kCtaForeground,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: i == active ? _kIndicatorActive : _kIndicatorIdle,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
