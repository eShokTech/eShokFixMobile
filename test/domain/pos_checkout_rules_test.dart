import 'package:flutter_test/flutter_test.dart';
import 'package:eshokfix_mobile/domain/pos_checkout_rules.dart';

void main() {
  group('PosCheckoutRules', () {
    test('converts USD cash to MXN using the configured exchange rate', () {
      expect(
        PosCheckoutRules.receivedInMxn(
          amount: 50,
          currency: 'USD',
          exchangeRate: 17.50,
        ),
        875,
      );
    });

    test('calculates large positive change for cash sales', () {
      final received = PosCheckoutRules.receivedInMxn(
        amount: 1000,
        currency: 'MXN',
      );
      expect(
        PosCheckoutRules.changeDue(
          saleTotal: 735.50,
          receivedInMxn: received,
        ),
        264.50,
      );
    });

    test('does not produce negative change when the amount is short', () {
      expect(
        PosCheckoutRules.changeDue(saleTotal: 800, receivedInMxn: 700),
        0,
      );
      expect(
        PosCheckoutRules.isSufficient(saleTotal: 800, receivedInMxn: 700),
        isFalse,
      );
    });

    test('rejects missing or invalid USD exchange rate', () {
      expect(
        () => PosCheckoutRules.receivedInMxn(amount: 10, currency: 'USD', exchangeRate: 0),
        throwsArgumentError,
      );
    });
  });
}
