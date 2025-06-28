import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:matchmaker/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Création de contenu', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Simuler une connexion directe (ou assure-toi d’être sur MainScreen)
    // Naviguer vers l'écran de création
    final addButton = find.byIcon(Icons.add);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    // Remplir le formulaire
    await tester.enterText(find.byKey(const Key('titleField')), 'Post de test');
    await tester.enterText(find.byKey(const Key('descriptionField')), 'Ceci est un contenu automatisé');

    // Publier
    final publishButton = find.text('Publier');
    expect(publishButton, findsOneWidget);
    await tester.tap(publishButton);
    await tester.pumpAndSettle();

    // Vérifier confirmation
    expect(find.textContaining('publié'), findsOneWidget);
  });
}
