import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/database_provider.dart';
import '../../../businesses/presentation/providers/active_business_provider.dart';
import '../../domain/entities/inventory_movement.dart';
import 'product_providers.dart';

final stockQuantityProvider = StreamProvider.family<int, String>((
  ref,
  productId,
) {
  final database = ref.watch(databaseProvider);
  final repository = ref.watch(inventoryRepositoryProvider);
  final businessId = ref.watch(activeBusinessProvider);
  return database
      .customSelect(
        'SELECT 1 FROM inventory_movements '
        'WHERE product_id = ? AND business_id = ?',
        variables: [
          Variable.withString(productId),
          Variable.withString(businessId),
        ],
        readsFrom: {database.inventoryMovements},
      )
      .watch()
      .asyncMap((_) => repository.getStockQuantity(productId));
});

final inventoryMovementsProvider =
    StreamProvider.family<List<InventoryMovement>, String>((ref, productId) {
      final database = ref.watch(databaseProvider);
      final repository = ref.watch(inventoryRepositoryProvider);
      final businessId = ref.watch(activeBusinessProvider);
      return (database.select(database.inventoryMovements)..where(
            (movement) =>
                movement.productId.equals(productId) &
                movement.businessId.equals(businessId),
          ))
          .watch()
          .asyncMap((_) => repository.getMovements(productId));
    });
