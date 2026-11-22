import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/inventory_movement.dart';
import 'product_providers.dart';

final stockQuantityProvider = FutureProvider.family<int, String>((
  ref,
  productId,
) {
  return ref.watch(inventoryRepositoryProvider).getStockQuantity(productId);
});

final inventoryMovementsProvider =
    FutureProvider.family<List<InventoryMovement>, String>((ref, productId) {
      return ref.watch(inventoryRepositoryProvider).getMovements(productId);
    });
