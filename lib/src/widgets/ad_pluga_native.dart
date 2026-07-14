import 'package:flutter/widgets.dart';

import '../ad_pluga.dart';
import '../errors.dart';
import '../models/serve_response.dart';
import '../viewability/visibility_tracker.dart';
import 'ad_pluga_banner.dart';

typedef AdPlugaNativeBuilder = Widget Function(
    BuildContext context, Ad ad, VoidCallback onClick);

class AdPlugaNative extends StatefulWidget {
  const AdPlugaNative({
    super.key,
    required this.slotId,
    required this.builder,
    this.format,
    this.onImpression,
    this.onError,
    this.placeholder,
  });

  final String slotId;
  final String? format;
  final AdPlugaNativeBuilder builder;
  final AdPlugaImpressionHandler? onImpression;
  final AdPlugaErrorHandler? onError;
  final Widget? placeholder;

  @override
  State<AdPlugaNative> createState() => _AdPlugaNativeState();
}

class _AdPlugaNativeState extends State<AdPlugaNative> {
  ServeResponse? _response;
  int? _visibilityHandle;
  bool _clickFired = false;
  bool _disposed = false;

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
        () {
          if (_disposed) return;
          ad.fireImpression(resp, widget.slotId);
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
    final resp = _response;
    if (resp == null) {
      return widget.placeholder ?? const SizedBox.shrink();
    }
    return widget.builder(context, resp.ad, _handleTap);
  }
}
