import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/database_provider.dart';
import '../../domain/entities/inventory_movement.dart';
import 'product_providers.dart';

final stockQuantityProvider = StreamProvider.family<int, String>((
  ref,
  productId,
) {
  final database = ref.watch(databaseProvider);
  final repository = ref.watch(inventoryRepositoryProvider);
  return database
      .customSelect(
        'SELECT COALESCE(SUM(quantity_delta), 0) AS stock '
        'FROM inventory_movements WHERE product_id = ?',
        variables: [Variable.withString(productId)],
        readsFrom: {database.inventoryMovements},
      )
      .watch()
      .asyncMap((_) => repository.getStockQuantity(productId));
});

final inventoryMovementsProvider =
    StreamProvider.family<List<InventoryMovement>, String>((ref, productId) {
      final database = ref.watch(databaseProvider);
      final repository = ref.watch(inventoryRepositoryProvider);
      return (database.select(database.inventoryMovements)
            ..where((movement) => movement.productId.equals(productId)))
          .watch()
          .asyncMap((_) => repository.getMovements(productId));
    });
