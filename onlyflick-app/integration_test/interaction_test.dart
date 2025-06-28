import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:matchmaker/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Liker un post et envoyer un commentaire', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Vérifie qu'on a un post avec compteur de likes
    final likeText = find.textContaining('likes');
    expect(likeText, findsWidgets);

    // Sauvegarde du nombre initial
    final initialLikeWidget = tester.widget<Text>(likeText.first);
    final initialLikes = int.tryParse(initialLikeWidget.data!.split(' ')[0]) ?? 0;

    // Appuie sur le bouton like
    final likeButton = find.byIcon(Icons.favorite_border).first;
    await tester.tap(likeButton);
    await tester.pumpAndSettle();

    // Vérifie incrément du like
    final updatedLikeWidget = tester.widget<Text>(likeText.first);
    final updatedLikes = int.tryParse(updatedLikeWidget.data!.split(' ')[0]) ?? 0;
    expect(updatedLikes, initialLikes + 1);

    // Touche le bouton commentaire
    final commentButton = find.byIcon(Icons.comment_outlined).first;
    await tester.tap(commentButton);
    await tester.pumpAndSettle();

    // Trouve le champ commentaire
    final commentField = find.byKey(const Key('commentField'));
    expect(commentField, findsOneWidget);
    await tester.enterText(commentField, 'Super post !');

    // Bouton envoyer
    final sendButton = find.byKey(const Key('sendComment'));
    await tester.tap(sendButton);
    await tester.pumpAndSettle();

    // Vérifie que le commentaire est affiché
    expect(find.text('Super post !'), findsOneWidget);
  });
}
