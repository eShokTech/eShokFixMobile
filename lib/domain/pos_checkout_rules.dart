import 'financial_rules.dart';

class PosCheckoutRules {
  const PosCheckoutRules._();

  static double receivedInMxn({
    required double amount,
    required String currency,
    double exchangeRate = 1,
  }) {
    if (!amount.isFinite || amount < 0) {
      throw ArgumentError('El importe recibido debe ser válido y no negativo.');
    }

    switch (currency.toUpperCase()) {
      case 'MXN':
        return FinancialRules.money(amount);
      case 'USD':
        if (!exchangeRate.isFinite || exchangeRate <= 0) {
          throw ArgumentError('El tipo de cambio debe ser mayor a cero.');
        }
        return FinancialRules.money(amount * exchangeRate);
      default:
        throw ArgumentError('La moneda recibida no está soportada.');
    }
  }

  static double changeDue({
    required double saleTotal,
    required double receivedInMxn,
  }) {
    if (!saleTotal.isFinite || saleTotal < 0 ||
        !receivedInMxn.isFinite || receivedInMxn < 0) {
      throw ArgumentError('El total y el importe recibido deben ser válidos.');
    }
    return FinancialRules.money(
      (receivedInMxn - saleTotal)
          .clamp(0.0, double.infinity)
          .toDouble(),
    );
  }

  static bool isSufficient({
    required double saleTotal,
    required double receivedInMxn,
  }) {
    if (!saleTotal.isFinite || saleTotal < 0 ||
        !receivedInMxn.isFinite || receivedInMxn < 0) {
      return false;
    }
    return receivedInMxn + 0.0001 >= saleTotal;
  }
}
