import 'package:flutter_test/flutter_test.dart';
import 'package:eshokfix_mobile/data/auth_service.dart';

void main() {
  group('AuthService role permissions', () {
    test('administrator has every permission', () {
      expect(AuthService.can('ADMIN', 'users.manage'), isTrue);
      expect(AuthService.can('ADMIN', 'settings.manage'), isTrue);
      expect(AuthService.can('ADMIN', 'cash.manage'), isTrue);
    });

    test('technician can operate workshop tasks but not money or administration', () {
      expect(AuthService.can('TECNICO', 'orders.view'), isTrue);
      expect(AuthService.can('TECNICO', 'orders.manage'), isTrue);
      expect(AuthService.can('TECNICO', 'inventory.view'), isTrue);
      expect(AuthService.can('TECNICO', 'orders.payments.view'), isTrue);
      expect(AuthService.can('TECNICO', 'settings.read'), isTrue);
      expect(AuthService.can('TECNICO', 'cash.view'), isFalse);
      expect(AuthService.can('TECNICO', 'sales.manage'), isFalse);
      expect(AuthService.can('TECNICO', 'users.manage'), isFalse);
      expect(AuthService.can('TECNICO', 'orders.cancel'), isFalse);
      expect(AuthService.can('TECNICO', 'clients.delete'), isFalse);
    });

    test('cashier can collect and sell but cannot edit workshop or inventory', () {
      expect(AuthService.can('CAJA', 'orders.view'), isTrue);
      expect(AuthService.can('CAJA', 'orders.pay'), isTrue);
      expect(AuthService.can('CAJA', 'sales.manage'), isTrue);
      expect(AuthService.can('CAJA', 'cash.manage'), isTrue);
      expect(AuthService.can('CAJA', 'orders.manage'), isFalse);
      expect(AuthService.can('CAJA', 'inventory.manage'), isFalse);
      expect(AuthService.can('CAJA', 'purchases.manage'), isFalse);
      expect(AuthService.can('CAJA', 'orders.cancel'), isFalse);
    });

    test('unknown roles are denied by default', () {
      expect(AuthService.can('INVITADO', 'orders.view'), isFalse);
      expect(AuthService.can('INVITADO', 'users.manage'), isFalse);
    });
  });
}
