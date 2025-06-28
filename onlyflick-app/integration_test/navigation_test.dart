import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:matchmaker/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Navigation entre les onglets', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    final icons = [
      Icons.home,
      Icons.search,
      Icons.video_library,
      Icons.favorite_border,
      Icons.person_outline,
    ];

    final expectedTexts = [
      'OnlyFlick', // Écran Feed
      'Recherche', // Écran Search
      'Profil',
    ];

    for (var i = 0; i < icons.length; i++) {
      await tester.tap(find.byIcon(icons[i]));
      await tester.pumpAndSettle();
      expect(find.text(expectedTexts[i]), findsOneWidget);
    }
  });
}
