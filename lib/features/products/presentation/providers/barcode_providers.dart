import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/database_provider.dart';
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
    StreamProvider.family<List<ProductBarcode>, String>((ref, productId) {
      final database = ref.watch(databaseProvider);
      final repository = ref.watch(barcodeRepositoryProvider);
      return (database.select(database.productBarcodes)
            ..where((barcode) => barcode.productId.equals(productId)))
          .watch()
          .asyncMap((_) => repository.getBarcodes(productId));
    });

final productByBarcodeProvider = FutureProvider.family<Product?, String>((
  ref,
  barcode,
) {
  return ref.watch(barcodeRepositoryProvider).getProductByBarcode(barcode);
});
