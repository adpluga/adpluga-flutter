import 'package:adpluga_flutter/adpluga_flutter.dart';
import 'package:flutter/material.dart';

// The public demo key: test mode, nothing is charged. Replace both with your
// own key and slot id from the dashboard.
const publishableKey = 'pk_test_kvhgusa3wauuklgogatyovhbohlpc';
const slotId = '35490c85-1933-4764-bf04-647005ea6db5';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdPluga.initialize(publisherKey: publishableKey);
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(title: 'adPluga example', home: HomePage());
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _showInterstitial(BuildContext context) async {
    try {
      final ad = await InterstitialAd.load(slotId: slotId);
      if (!context.mounted) return;
      await ad.show(context);
    } on AdPlugaError catch (e) {
      debugPrint('adpluga: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('adPluga in Flutter')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdPlugaBanner(
              slotId: slotId,
              onError: (err) => debugPrint('adpluga: $err'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => _showInterstitial(context),
              child: const Text('Show an interstitial'),
            ),
          ],
        ),
      ),
    );
  }
}
