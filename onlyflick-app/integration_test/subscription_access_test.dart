import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:matchmaker/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Accès au contenu premium selon abonnement', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Par défaut l'utilisateur n'est pas abonné
    expect(find.text('Contenu réservé aux abonnés'), findsOneWidget);
    expect(find.text('Contenu Premium'), findsNothing);

    // Cliquer sur le bouton pour simuler un abonnement
    final subscribeButton = find.byKey(const Key('subscribeButton'));
    await tester.tap(subscribeButton);
    await tester.pumpAndSettle();

    // Le contenu premium devient visible
    expect(find.text('Contenu Premium'), findsOneWidget);
    expect(find.text('Contenu réservé aux abonnés'), findsNothing);
  });
}
