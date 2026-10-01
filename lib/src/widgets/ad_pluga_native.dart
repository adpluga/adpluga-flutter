import 'package:flutter/widgets.dart';

import '../ad_pluga.dart';
import '../errors.dart';
import '../models/serve_response.dart';
import '../viewability/visibility_tracker.dart';
import 'ad_pluga_banner.dart';
import 'test_badge.dart';

/// Builds the host app's layout for a native [ad].
///
/// Call [onClick] when the user taps the ad; only the first call is reported.
/// It does not open the advertiser destination.
typedef AdPlugaNativeBuilder = Widget Function(
    BuildContext context, Ad ad, VoidCallback onClick);

/// Loads an ad for [slotId] and hands it to [builder] to lay out.
///
/// The impression and viewability are reported once the widget has been at
/// least 50% on screen for one second. Unlike [AdPlugaBanner], it neither
/// rotates nor retries after a failed load.
///
/// Requires `AdPluga.initialize` to have been called.
class AdPlugaNative extends StatefulWidget {
  /// Creates a native ad slot for [slotId] rendered by [builder].
  const AdPlugaNative({
    super.key,
    required this.slotId,
    required this.builder,
    this.format,
    this.onImpression,
    this.onError,
    this.placeholder,
  });

  /// Slot identifier from the AdPluga dashboard.
  final String slotId;

  /// Creative format requested from the server; any when null.
  final String? format;

  /// Builds the ad layout once an ad is loaded.
  final AdPlugaNativeBuilder builder;

  /// Called after the impression is reported.
  final AdPlugaImpressionHandler? onImpression;

  /// Called when a load fails.
  final AdPlugaErrorHandler? onError;

  /// Shown until an ad is loaded.
  final Widget? placeholder;

  @override
  State<AdPlugaNative> createState() => _AdPlugaNativeState();
}

class _AdPlugaNativeState extends State<AdPlugaNative> {
  ServeResponse? _response;
  int? _visibilityHandle;
  bool _clickFired = false;
  bool _disposed = false;
  // Read in build, where depending on an inherited widget is legal, and probed
  // from the viewability tick.
  bool _painting = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdPlugaNative oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slotId != widget.slotId) {
      _teardown();
      _response = null;
      _clickFired = false;
      _load();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _teardown();
    super.dispose();
  }

  Future<void> _load() async {
    final ad = AdPluga.maybeInstance;
    if (ad == null) {
      widget.onError?.call(const NotInitializedError());
      return;
    }
    try {
      final resp = await ad.serve(slotId: widget.slotId, format: widget.format);
      if (_disposed) return;
      if (resp == null) {
        widget.onError?.call(const NetworkError('no fill'));
        return;
      }
      setState(() => _response = resp);
      _visibilityHandle = VisibilityTracker.instance.register(
        () => context.findRenderObject() as RenderBox?,
        isPainting: () => _painting,
        () {
          if (_disposed) return;
          ad.fireImpression(resp, widget.slotId);
          ad.fireViewable(resp, widget.slotId);
          widget.onImpression?.call();
        },
      );
    } on AdPlugaError catch (e) {
      widget.onError?.call(e);
    }
  }

  void _teardown() {
    final h = _visibilityHandle;
    if (h != null) {
      VisibilityTracker.instance.unregister(h);
      _visibilityHandle = null;
    }
  }

  void _handleTap() {
    final sdk = AdPluga.maybeInstance;
    final resp = _response;
    if (sdk == null || resp == null || _clickFired) return;
    _clickFired = true;
    sdk.fireClick(resp, widget.slotId);
  }

  @override
  Widget build(BuildContext context) {
    _painting = Visibility.of(context);
    final resp = _response;
    if (resp == null) {
      return widget.placeholder ?? const SizedBox.shrink();
    }
    return withTestBadge(
      widget.builder(context, resp.ad, _handleTap),
      isTest: resp.ad.isTest,
    );
  }
}
