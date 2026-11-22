import '../entities/sale_checkout_item.dart';
import '../entities/sale_checkout_result.dart';
import '../repositories/sale_repository.dart';

class SaleCheckoutService {
  final SaleRepository repository;

  SaleCheckoutService({required this.repository});

  Future<SaleCheckoutResult> checkout({
    required List<SaleCheckoutItem> items,
    required String paymentMethod,
    required int amountTenderedCentavos,
    String? referenceNumber,
  }) {
    return repository.checkout(
      items: items,
      paymentMethod: paymentMethod,
      amountTenderedCentavos: amountTenderedCentavos,
      referenceNumber: referenceNumber,
    );
  }
}
