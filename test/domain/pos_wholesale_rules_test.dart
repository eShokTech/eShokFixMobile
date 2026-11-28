import 'package:flutter_test/flutter_test.dart';
import 'package:eshokfix_mobile/domain/pos_wholesale_rules.dart';

void main() {
  group('PosWholesaleRules', () {
    test('fixed wholesale discount subtracts amount from each unit', () {
      expect(
        PosWholesaleRules.unitPriceAfterDiscount(
          unitPrice: 100,
          type: 'fixed',
          value: 20,
        ),
        80,
      );
    });

    test('fixed discount never creates a negative unit price', () {
      expect(
        PosWholesaleRules.unitPriceAfterDiscount(
          unitPrice: 12,
          type: 'fixed',
          value: 20,
        ),
        0,
      );
    });

    test('percentage discount calculates final unit price', () {
      expect(
        PosWholesaleRules.unitPriceAfterDiscount(
          unitPrice: 200,
          type: 'percentage',
          value: 15,
        ),
        170,
      );
    });

    test('percentage discount cannot exceed 100 percent', () {
      expect(
        () => PosWholesaleRules.unitPriceAfterDiscount(
          unitPrice: 100,
          type: 'percentage',
          value: 105,
        ),
        throwsArgumentError,
      );
    });

    test('unknown discount type is rejected', () {
      expect(
        () => PosWholesaleRules.unitPriceAfterDiscount(
          unitPrice: 100,
          type: 'unknown',
          value: 10,
        ),
        throwsArgumentError,
      );
    });
  });
}
