class FinancialRules {
  static const Set<String> paymentMethods = {'EFECTIVO', 'TRANSFERENCIA', 'TARJETA', 'OTRO'};

  static int cents(double value) {
    if (!value.isFinite) throw ArgumentError('El importe debe ser finito.');
    return (value * 100).round();
  }

  static double money(double value) => cents(value) / 100.0;

  static List<Map<String, Object?>> normalizePayments({
    required double total,
    required String fallbackMethod,
    List<Map<String, Object?>>? payments,
  }) {
    final totalCents = cents(total);
    if (totalCents < 0) throw ArgumentError('El total no puede ser negativo.');
    final normalizedFallback = fallbackMethod.trim().toUpperCase();
    if (!paymentMethods.contains(normalizedFallback)) {
      throw ArgumentError('Selecciona un medio de pago válido.');
    }
    if (totalCents == 0) {
      if (payments != null && payments.isNotEmpty) throw ArgumentError('No se pueden registrar pagos para un importe de cero.');
      return [];
    }
    final source = payments ?? [{'method': normalizedFallback, 'amount': total}];
    if (source.isEmpty) throw ArgumentError('Registra al menos un medio de pago.');
    final normalized = <Map<String, Object?>>[];
    var sum = 0;
    for (final part in source) {
      final method = (part['method'] ?? '').toString().trim().toUpperCase();
      final value = part['amount'];
      if (!paymentMethods.contains(method) || value is! num) {
        throw ArgumentError('Cada pago necesita un medio válido y un importe numérico.');
      }
      final amountCents = cents(value.toDouble());
      if (amountCents <= 0) throw ArgumentError('Cada importe de pago debe ser mayor a cero.');
      sum += amountCents;
      normalized.add({'method': method, 'amount': amountCents / 100.0});
    }
    if (sum != totalCents) throw ArgumentError('La suma de los medios de pago debe coincidir exactamente con el total.');
    return normalized;
  }

  static double remainingQuantity(double total, double returned) {
    if (!total.isFinite || !returned.isFinite || total < 0 || returned < 0 || returned > total + 0.000001) {
      throw ArgumentError('Las cantidades de devolución no son válidas.');
    }
    return (total - returned).clamp(0.0, double.infinity).toDouble();
  }

  static double saleLineRefund({
    required double quantity,
    required double unitPrice,
    required double saleSubtotal,
    required double saleTotal,
  }) {
    if (!quantity.isFinite || !unitPrice.isFinite || !saleSubtotal.isFinite || !saleTotal.isFinite ||
        quantity <= 0 || unitPrice < 0 || saleSubtotal < 0 || saleTotal < 0 || saleTotal > saleSubtotal + 0.01) {
      throw ArgumentError('Los datos de la partida a devolver no son válidos.');
    }
    if (saleSubtotal <= 0) return 0;
    return money(quantity * unitPrice * (saleTotal / saleSubtotal));
  }

  static double supplierCashRefund({
    required double purchaseTotal,
    required double paid,
    required double returnAmount,
  }) {
    if (!purchaseTotal.isFinite || !paid.isFinite || !returnAmount.isFinite ||
        purchaseTotal < 0 || paid < 0 || returnAmount < 0) {
      throw ArgumentError('Los importes de la devolución no son válidos.');
    }
    final netTotal = (purchaseTotal - returnAmount).clamp(0.0, double.infinity);
    return money((paid - netTotal).clamp(0.0, double.infinity).toDouble());
  }
}
