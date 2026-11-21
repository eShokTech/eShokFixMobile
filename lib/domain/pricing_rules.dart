import 'financial_rules.dart';

class ProductPricingRules {
  static const directCost = 'DIRECT_COST';
  static const fixedProfit = 'FIXED_PROFIT';
  static const percentageProfit = 'PERCENTAGE_PROFIT';
  static const percentageSale = 'PERCENTAGE_SALE';

  static const methods = <String>{
    directCost,
    fixedProfit,
    percentageProfit,
    percentageSale,
  };

  static double suggestedPrice({
    required double cost,
    required String method,
    double value = 0,
  }) {
    if (!cost.isFinite || cost < 0 || !value.isFinite || value < 0) {
      throw ArgumentError('El costo y la regla deben ser importes válidos no negativos.');
    }
    if (!methods.contains(method)) {
      throw ArgumentError('El método de cálculo de precio no es válido.');
    }
    final normalizedCost = FinancialRules.money(cost);
    final normalizedValue = FinancialRules.money(value);
    switch (method) {
      case fixedProfit:
        return FinancialRules.money(normalizedCost + normalizedValue);
      case percentageProfit:
        return FinancialRules.money(normalizedCost * (1 + normalizedValue / 100));
      case percentageSale:
        if (normalizedValue >= 100) {
          throw ArgumentError('El margen sobre venta debe ser menor a 100%.');
        }
        if (normalizedValue == 0) return normalizedCost;
        return FinancialRules.money(normalizedCost / (1 - normalizedValue / 100));
      case directCost:
        return normalizedCost;
    }
    throw ArgumentError('El método de cálculo de precio no es válido.');
  }

  static Map<String, double?> metrics({
    required double cost,
    required double salePrice,
  }) {
    if (!cost.isFinite || !salePrice.isFinite || cost < 0 || salePrice < 0) {
      throw ArgumentError('El costo y el precio deben ser valores válidos no negativos.');
    }
    final profit = FinancialRules.money(salePrice - cost);
    return {
      'profit': profit,
      'markup_percent': cost > 0 ? (profit / cost) * 100 : null,
      'margin_percent': salePrice > 0 ? (profit / salePrice) * 100 : null,
    };
  }

  static String methodLabel(String method) => switch (method) {
    directCost => 'Costo directo',
    fixedProfit => 'Ganancia fija',
    percentageProfit => 'Porcentaje sobre costo',
    percentageSale => 'Margen sobre precio de venta',
    _ => 'Método desconocido',
  };
}
