class PosWholesaleRules {
  /// A fixed discount subtracts the configured amount from every unit.
  /// Percentage discounts apply to the original unit price.
  /// The result is clamped to zero and rounded to cents.
  static double unitPriceAfterDiscount({
    required double unitPrice,
    required String type,
    required double value,
  }) {
    if (!unitPrice.isFinite || unitPrice < 0) {
      throw ArgumentError.value(unitPrice, 'unitPrice', 'Debe ser un precio válido no negativo.');
    }
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(value, 'value', 'El descuento debe ser válido y no negativo.');
    }

    final normalizedType = type.trim().toLowerCase();
    double result;
    if (normalizedType == 'fixed') {
      result = unitPrice - value;
    } else if (normalizedType == 'percentage') {
      if (value > 100) {
        throw ArgumentError.value(value, 'value', 'El porcentaje no puede superar 100.');
      }
      result = unitPrice * (1 - value / 100);
    } else {
      throw ArgumentError.value(type, 'type', 'El tipo debe ser fixed o percentage.');
    }

    final clamped = result < 0 ? 0.0 : result;
    return (clamped * 100).roundToDouble() / 100;
  }
}
