import 'package:flutter_test/flutter_test.dart';
import 'package:eshokfix_mobile/domain/workflow.dart';
import 'package:eshokfix_mobile/domain/financial_rules.dart';

void main() {
  group('OrderWorkflow', () {
    test('allows the normal repair lifecycle', () {
      expect(OrderWorkflow.canTransition('RECIBIDO', 'DIAGNOSTICO'), isTrue);
      expect(OrderWorkflow.canTransition('DIAGNOSTICO', 'ESPERA_AUTORIZACION'), isTrue);
      expect(OrderWorkflow.canTransition('ESPERA_AUTORIZACION', 'REPARACION'), isTrue);
      expect(OrderWorkflow.canTransition('REPARACION', 'PRUEBAS'), isTrue);
      expect(OrderWorkflow.canTransition('PRUEBAS', 'LISTO'), isTrue);
      expect(OrderWorkflow.canTransition('LISTO', 'ENTREGADO'), isTrue);
    });

    test('blocks skipping required workflow steps', () {
      expect(OrderWorkflow.canTransition('RECIBIDO', 'LISTO'), isFalse);
      expect(OrderWorkflow.canTransition('DIAGNOSTICO', 'REPARACION'), isFalse);
      expect(OrderWorkflow.canTransition('DIAGNOSTICO', 'ESPERA_REFACCION'), isFalse);
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


  group('FinancialRules', () {
    test('validates single and split tender exactly', () {
      expect(FinancialRules.normalizePayments(total: 250, fallbackMethod: 'EFECTIVO'), [
        {'method': 'EFECTIVO', 'amount': 250.0},
      ]);
      expect(FinancialRules.normalizePayments(total: 250, fallbackMethod: 'EFECTIVO', payments: [
        {'method': 'EFECTIVO', 'amount': 100},
        {'method': 'TARJETA', 'amount': 150},
      ]), [
        {'method': 'EFECTIVO', 'amount': 100.0},
        {'method': 'TARJETA', 'amount': 150.0},
      ]);
    });

    test('rejects tender mismatches and unsupported methods', () {
      expect(() => FinancialRules.normalizePayments(total: 100, fallbackMethod: 'EFECTIVO',
        payments: [{'method': 'EFECTIVO', 'amount': 99}]), throwsArgumentError);
      expect(() => FinancialRules.normalizePayments(total: 100, fallbackMethod: 'EFECTIVO',
        payments: [{'method': 'BITCOIN', 'amount': 100}]), throwsArgumentError);
    });

    test('calculates returned balances and discount-adjusted refunds', () {
      expect(FinancialRules.remainingQuantity(5, 2), 3);
      expect(FinancialRules.saleLineRefund(quantity: 1, unitPrice: 100, saleSubtotal: 200, saleTotal: 180), 90);
    });

    test('calculates supplier cash refund only after payable is cleared', () {
      expect(FinancialRules.supplierCashRefund(purchaseTotal: 500, paid: 200, returnAmount: 100), 0);
      expect(FinancialRules.supplierCashRefund(purchaseTotal: 500, paid: 500, returnAmount: 100), 100);
    });
  });

}
