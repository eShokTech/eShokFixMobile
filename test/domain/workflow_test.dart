import 'package:flutter_test/flutter_test.dart';
import 'package:eshokfix_mobile/domain/workflow.dart';

void main() {
  group('OrderWorkflow', () {
    test('allows the normal repair lifecycle', () {
      expect(OrderWorkflow.canTransition('RECIBIDO', 'DIAGNOSTICO'), isTrue);
      expect(OrderWorkflow.canTransition('DIAGNOSTICO', 'REPARACION'), isTrue);
      expect(OrderWorkflow.canTransition('REPARACION', 'PRUEBAS'), isTrue);
      expect(OrderWorkflow.canTransition('PRUEBAS', 'LISTO'), isTrue);
      expect(OrderWorkflow.canTransition('LISTO', 'ENTREGADO'), isTrue);
    });

    test('blocks skipping required workflow steps', () {
      expect(OrderWorkflow.canTransition('RECIBIDO', 'LISTO'), isFalse);
      expect(OrderWorkflow.canTransition('DIAGNOSTICO', 'ENTREGADO'), isFalse);
      expect(OrderWorkflow.canTransition('ENTREGADO', 'REPARACION'), isFalse);
    });

    test('allows a delivered order to remain in its current state', () {
      expect(OrderWorkflow.canTransition('ENTREGADO', 'ENTREGADO'), isTrue);
    });

    test('provides readable labels for all known states', () {
      expect(OrderWorkflow.label('ESPERA_AUTORIZACION'), 'Esperando autorización');
      expect(OrderWorkflow.label('LISTO'), 'Listo para entregar');
    });
  });

  group('PurchaseAccounting', () {
    test('calculates line and purchase totals', () {
      expect(PurchaseAccounting.lineTotal(3, 125), 375);
      expect(PurchaseAccounting.total(375, 25), 350);
    });

    test('keeps balances non-negative', () {
      expect(PurchaseAccounting.balance(350, 100), 250);
      expect(PurchaseAccounting.balance(350, 400), 0);
      expect(PurchaseAccounting.total(100, 150), 0);
    });

    test('classifies pending, partial and paid purchases', () {
      expect(PurchaseAccounting.paymentStatus(350, 0), 'PENDIENTE');
      expect(PurchaseAccounting.paymentStatus(350, 100), 'PARCIAL');
      expect(PurchaseAccounting.paymentStatus(350, 350), 'PAGADA');
      expect(PurchaseAccounting.paymentStatus(350, 351), 'PAGADA');
    });
  });


  group('OrderPartAccounting', () {
    test('calculates material line totals', () {
      expect(OrderPartAccounting.lineTotal(2, 180), 360);
    });

    test('recalculates order total with labor, parts and discount', () {
      expect(OrderPartAccounting.orderTotal(labor: 350, parts: 180, discount: 30), 500);
      expect(OrderPartAccounting.orderTotal(labor: 100, parts: 0, discount: 150), 0);
    });
  });

}
