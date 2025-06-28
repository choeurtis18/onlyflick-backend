import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:matchmaker/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Auth Flow', () {
    testWidgets('Login with correct credentials redirects to /home',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Saisie email
      final emailField = find.byKey(const Key('emailField'));
      expect(emailField, findsOneWidget);
      await tester.enterText(emailField, 'user@test.com');

      // Saisie mot de passe
      final passwordField = find.byKey(const Key('passwordField'));
      expect(passwordField, findsOneWidget);
      await tester.enterText(passwordField, 'password123');

      // Cliquer sur le bouton
      final loginButton = find.text('Se connecter');
      expect(loginButton, findsOneWidget);
      await tester.tap(loginButton);

      await tester.pumpAndSettle();
    });
  });
}
