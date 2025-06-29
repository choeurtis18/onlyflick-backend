import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:matchmaker/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Auth Flow', () {
    testWidgets('Login with correct credentials redirects to home screen', (
      WidgetTester tester,
    ) async {
      // Configuration - réduire l'animation
      await tester.pumpWidget(const MaterialApp());
      await tester.pumpAndSettle();

      // Démarrer l'application
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Attendre que l'écran de login soit visible
      expect(
        find.text('Se connecter').first.evaluate().isNotEmpty ? find.text('Se connecter') : find.text('Connexion'),
        findsOneWidget,
      );

      // Saisie email (recherche par key ou par type si key non disponible)
      final emailField = find.byKey(const Key('emailField')).evaluate().isEmpty
          ? find.byType(TextFormField).first
          : find.byKey(const Key('emailField'));
      expect(emailField, findsOneWidget);
      await tester.enterText(emailField, 'user@test.com');

      // Saisie mot de passe
      final passwordField =
          find.byKey(const Key('passwordField')).evaluate().isEmpty
          ? find.byType(TextFormField).last
          : find.byKey(const Key('passwordField'));
      expect(passwordField, findsOneWidget);
      await tester.enterText(passwordField, 'password123');

      // Cliquer sur le bouton de connexion
      final loginButton = find.text('Se connecter').first.evaluate().isNotEmpty ? find.text('Se connecter') : find.text('Connexion');
      expect(loginButton, findsOneWidget);
      await tester.tap(loginButton);

      // Attendre le chargement
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Vérifier que la navigation a réussi (trouve soit le titre "OnlyFlick" soit la BottomNavigationBar)
      expect(
        find.text('OnlyFlick').evaluate().isNotEmpty || find.byType(BottomNavigationBar).evaluate().isNotEmpty,
        isTrue,
        reason: "L'utilisateur devrait être connecté et voir l'écran principal",
      );
    });
  });
}
