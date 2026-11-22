import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/inventory_management_service.dart';
import 'product_providers.dart';

final inventoryManagementServiceProvider = Provider<InventoryManagementService>(
  (ref) {
    return InventoryManagementService(
      inventoryRepository: ref.watch(inventoryRepositoryProvider),
      productRepository: ref.watch(productRepositoryProvider),
    );
  },
);
