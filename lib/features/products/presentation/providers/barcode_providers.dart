import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/product_barcode.dart';
import '../../domain/services/barcode_management_service.dart';
import 'product_providers.dart';

final barcodeManagementServiceProvider = Provider<BarcodeManagementService>((
  ref,
) {
  return BarcodeManagementService(
    repository: ref.watch(barcodeRepositoryProvider),
  );
});

final productBarcodesProvider =
    FutureProvider.family<List<ProductBarcode>, String>((ref, productId) {
      return ref.watch(barcodeRepositoryProvider).getBarcodes(productId);
    });

final productByBarcodeProvider = FutureProvider.family<Product?, String>((
  ref,
  barcode,
) {
  return ref.watch(barcodeRepositoryProvider).getProductByBarcode(barcode);
});
