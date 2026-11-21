import 'package:flutter_test/flutter_test.dart';
import 'package:eshokfix_mobile/domain/pricing_rules.dart';

void main() {
  group('ProductPricingRules', () {
    test('supports direct cost and fixed profit pricing', () {
      expect(
        ProductPricingRules.suggestedPrice(
          cost: 100, method: ProductPricingRules.directCost,
        ),
        100,
      );
      expect(
        ProductPricingRules.suggestedPrice(
          cost: 100, method: ProductPricingRules.fixedProfit, value: 35,
        ),
        135,
      );
    });

    test('distinguishes percentage over cost from margin over final sale', () {
      final markup = ProductPricingRules.suggestedPrice(
        cost: 100, method: ProductPricingRules.percentageProfit, value: 30,
      );
      final margin = ProductPricingRules.suggestedPrice(
        cost: 100, method: ProductPricingRules.percentageSale, value: 30,
      );

      expect(markup, 130);
      expect(margin, 142.86);
      expect(margin, greaterThan(markup));
    });

    test('rejects impossible sale margin and invalid input', () {
      expect(
        () => ProductPricingRules.suggestedPrice(
          cost: 100, method: ProductPricingRules.percentageSale, value: 100,
        ),
        throwsArgumentError,
      );
      expect(
        () => ProductPricingRules.suggestedPrice(
          cost: -1, method: ProductPricingRules.fixedProfit, value: 20,
        ),
        throwsArgumentError,
      );
    });

    test('calculates actual profit, markup and margin', () {
      final values = ProductPricingRules.metrics(cost: 100, salePrice: 150);

      expect(values['profit'], 50);
      expect(values['markup_percent'], 50);
      expect(values['margin_percent'], closeTo(33.333333, 0.0001));
    });

    test('does not invent a percentage when denominators are zero', () {
      final values = ProductPricingRules.metrics(cost: 0, salePrice: 0);

      expect(values['profit'], 0);
      expect(values['markup_percent'], isNull);
      expect(values['margin_percent'], isNull);
    });

    test('preserves losses when sale price is below cost', () {
      final values = ProductPricingRules.metrics(cost: 120, salePrice: 100);

      expect(values['profit'], -20);
      expect(values['margin_percent'], -20);
    });
  });
}
