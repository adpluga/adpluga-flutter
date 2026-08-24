import 'package:flutter/widgets.dart';

const Color _kTestBadgeBackground = Color(0xFFB45309);
const Color _kTestBadgeForeground = Color(0xFFFFFFFF);

/// Non-interactive marker drawn over sandbox (pk_test_*) creatives.
class TestBadge extends StatelessWidget {
  const TestBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _kTestBadgeBackground,
          borderRadius: BorderRadius.all(Radius.circular(3)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            'TEST',
            textDirection: TextDirection.ltr,
            style: TextStyle(
              color: _kTestBadgeForeground,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Overlays a top-left [TestBadge] on [child] when [isTest] is true. The badge
/// never intercepts pointer events, so taps still reach the creative below.
Widget withTestBadge(Widget child, {required bool isTest}) {
  if (!isTest) return child;
  return Stack(
    alignment: Alignment.topLeft,
    children: [
      child,
      const Positioned(top: 4, left: 4, child: TestBadge()),
    ],
  );
}
