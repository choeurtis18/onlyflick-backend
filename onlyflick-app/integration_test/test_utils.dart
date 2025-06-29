import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class TestUtils {
  /// Tente de trouver un élément par clé, puis par texte, puis par type
  static Finder findElement(String key, String text, Type type) {
    final byKey = find.byKey(Key(key));
    if (byKey.evaluate().isNotEmpty) return byKey;

    final byText = find.text(text);
    if (byText.evaluate().isNotEmpty) return byText;

    return find.byType(type);
  }

  /// Vérifie si l'utilisateur est connecté
  static Future<bool> isLoggedIn(WidgetTester tester) async {
    await tester.pump();
    return find.byType(BottomNavigationBar).evaluate().isNotEmpty;
  }

  /// Se connecte avec des identifiants de test
  static Future<void> login(
    WidgetTester tester, {
    String email = 'user@test.com',
    String password = 'password123',
  }) async {
    // Saisie email
    final emailField = find.byType(TextFormField).first;
    await tester.enterText(emailField, email);

    // Saisie mot de passe
    final passwordField = find.byType(TextFormField).last;
    await tester.enterText(passwordField, password);

    // Cliquer sur le bouton
    final loginButton = find.byWidgetPredicate((widget) {
      if (widget is Text) {
        return widget.data == 'Se connecter' || widget.data == 'Connexion';
      }
      return false;
    }).first;
    await tester.tap(loginButton);
    await tester.pumpAndSettle();
  }

  /// Patiente jusqu'à ce que la condition soit vraie ou que le timeout soit atteint
  static Future<bool> waitUntil(
    WidgetTester tester,
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final endTime = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(endTime)) {
      if (condition()) return true;
      await tester.pump(const Duration(milliseconds: 100));
    }
    return false;
  }
}
