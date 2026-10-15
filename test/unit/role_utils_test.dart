import 'package:flutter_test/flutter_test.dart';
import 'package:riyal1/core/utils/role_utils.dart';

void main() {
  group('RoleUtils Unit Tests', () {
    test('fallbackAdminEmail is non-empty and formatted as email', () {
      expect(RoleUtils.fallbackAdminEmail, isNotEmpty);
      expect(RoleUtils.fallbackAdminEmail, contains('@'));
      expect(RoleUtils.fallbackAdminEmail, contains('.'));
    });
  });
}
