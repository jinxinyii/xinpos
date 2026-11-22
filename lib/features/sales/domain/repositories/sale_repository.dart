import '../entities/sale_checkout_item.dart';
import '../entities/sale_checkout_result.dart';

abstract class SaleRepository {
  Future<SaleCheckoutResult> checkout({
    required List<SaleCheckoutItem> items,
    required String paymentMethod,
    required int amountTenderedCentavos,
    String? referenceNumber,
  });
}
