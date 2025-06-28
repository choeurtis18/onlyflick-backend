import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:matchmaker/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Responsive UI test (resize window)', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Taille normale (desktop)
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpAndSettle();

    // Vérifie que la bottom nav est bien affichée
    expect(find.byType(BottomNavigationBar), findsOneWidget);

    // Resize mobile
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 2.0;
    await tester.pumpAndSettle();

    // Vérifie que la navigation est toujours fonctionnelle
    expect(find.byType(BottomNavigationBar), findsOneWidget);

    // Teste que le contenu principal est toujours là
    expect(find.text('OnlyFlick'), findsOneWidget);
  });
}
