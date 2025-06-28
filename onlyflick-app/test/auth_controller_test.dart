import 'package:flutter_test/flutter_test.dart';
import 'package:matchmaker/features/auth/auth_controller.dart';
import 'package:matchmaker/features/auth/auth_service.dart';

void main() {
  group('AuthController', () {
    late AuthService authService;
    late AuthController controller;

    setUp(() {
      authService = AuthService();
      controller = AuthController(authService);
    });

    test('login returns null on success', () {
      final result = controller.login('user@test.com', 'password123');
      expect(result, isNull);
    });

    test('login returns error message on failure', () {
      final result = controller.login('user@test.com', 'wrong');
      expect(result, 'Identifiants incorrects');
    });

    test('register returns null when successful', () {
      final result = controller.register('newuser@test.com', 'mypassword');
      expect(result, isNull);
    });

    test('register returns error when email already exists', () {
      controller.register('exist@test.com', 'pwd');
      final result = controller.register('exist@test.com', 'pwd');
      expect(result, 'Email déjà utilisé');
    });
  });
}
