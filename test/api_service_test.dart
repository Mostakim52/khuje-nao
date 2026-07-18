import 'package:flutter_test/flutter_test.dart';
import 'package:khuje_nao/api_service.dart';

void main() {
  group('ApiService', () {
    late ApiService apiService;

    setUp(() {
      apiService = ApiService();
    });

    test('signup returns response map for invalid name', () async {
      final result = await apiService.signup(
        email: 'test@example.com',
        password: 'Password123',
        name: 'o',
      );
      expect(result, isA<Map<String, dynamic>>());
    });

    test('signup returns response map for valid input', () async {
      final result = await apiService.signup(
        email: 'test@example.com',
        password: 'Password123',
        name: 'John Doe',
      );
      expect(result, isA<Map<String, dynamic>>());
    });

    test('login returns response map for invalid email', () async {
      final result = await apiService.login(
        email: 'invalid-email',
        password: 'Password123',
      );
      expect(result, isA<Map<String, dynamic>>());
    });

    test('login returns response map for valid input', () async {
      final result = await apiService.login(
        email: 'test@example.com',
        password: 'Password123',
      );
      expect(result, isA<Map<String, dynamic>>());
    });
  });
}
