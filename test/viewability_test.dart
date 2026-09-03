import 'package:adpluga_flutter/src/viewability/visibility_tracker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// Geometry alone reports both of these fully viewable, which is how impressions
// were billed for ads nobody could see: a hidden IndexedStack page keeps its
// position and size, and a box inside a collapsed viewport keeps its full
// height because the viewport hands it an unbounded constraint.
void main() {
  final tracker = VisibilityTracker.instance;

  testWidgets('a box on a hidden IndexedStack page is not viewable',
      (tester) async {
    final probes = <int, bool>{};
    final keys = <int, GlobalKey>{0: GlobalKey(), 1: GlobalKey()};

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: IndexedStack(
          index: 0,
          children: [
            for (var i = 0; i < 2; i++)
              _Probe(
                key: keys[i],
                onBuild: (painting) => probes[i] = painting,
              ),
          ],
        ),
      ),
    );

    expect(probes[0], isTrue, reason: 'the selected page paints');
    expect(probes[1], isFalse, reason: 'the hidden page must not count');

    // Geometry cannot tell them apart: both boxes keep a real rect.
    for (final key in keys.values) {
      final box = key.currentContext!.findRenderObject() as RenderBox;
      expect(box.hasSize, isTrue);
    }

    expect(
      tracker.isVisible(
        () => keys[1]!.currentContext!.findRenderObject() as RenderBox?,
        isPainting: () => probes[1]!,
      ),
      isFalse,
    );
  });

  testWidgets('a box inside a collapsed viewport is not viewable',
      (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        // A tight root constraint would override a zero height, so the
        // collapsed box has to sit under a loose one -- which is exactly the
        // shape a real app produces (a page whose body collapses).
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            height: 0,
            width: 440,
            child: SingleChildScrollView(
              child: SizedBox(key: key, width: 440, height: 212),
            ),
          ),
        ),
      ),
    );

    final box = key.currentContext!.findRenderObject() as RenderBox;
    // The box really is laid out at full height, at the origin, even though
    // nothing of it reaches the screen.
    expect(box.size.height, 212);
    expect(box.localToGlobal(Offset.zero), Offset.zero);
    expect(
      tracker.isVisible(() => box),
      isFalse,
      reason: 'the viewport clips it to nothing',
    );
  });

  testWidgets('an on-screen box stays viewable', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: SizedBox(key: key, width: 300, height: 250)),
      ),
    );
    final box = key.currentContext!.findRenderObject() as RenderBox;
    expect(tracker.isVisible(() => box), isTrue);
  });
}

class _Probe extends StatelessWidget {
  const _Probe({super.key, required this.onBuild});

  final void Function(bool painting) onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild(Visibility.of(context));
    return const SizedBox(width: 300, height: 250);
  }
}
