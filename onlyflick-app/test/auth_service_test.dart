import 'package:flutter_test/flutter_test.dart';
import 'package:matchmaker/features/auth/auth_service.dart';

void main() {
  group('AuthService', () {
    late AuthService authService;

    setUp(() {
      authService = AuthService();
    });

    test('login with correct credentials returns true', () {
      final result = authService.login('user@test.com', 'password123');
      expect(result, true);
    });

    test('login with incorrect credentials returns false', () {
      final result = authService.login('user@test.com', 'wrongpass');
      expect(result, false);
    });

    test('register with new email succeeds', () {
      final result = authService.register('new@test.com', 'newpass');
      expect(result, true);
    });

    test('register with existing email fails', () {
      authService.register('duplicate@test.com', '123456');
      final result = authService.register('duplicate@test.com', '123456');
      expect(result, false);
    });
  });
}
