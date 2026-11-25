import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/inventory_movement.dart' as domain;
import '../../domain/repositories/inventory_repository.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  final AppDatabase database;

  final String businessId;

  InventoryRepositoryImpl(this.database, this.businessId);

  @override
  Future<int> getStockQuantity(String productId) async {
    final result = await database
        .customSelect(
          'SELECT COALESCE(SUM(quantity_delta), 0) AS stock '
          'FROM inventory_movements WHERE product_id = ? AND business_id = ?',
          variables: [
            Variable.withString(productId),
            Variable.withString(businessId),
          ],
          readsFrom: {database.inventoryMovements},
        )
        .getSingle();

    return result.read<int>('stock');
  }

  @override
  Future<List<domain.InventoryMovement>> getMovements(String productId) async {
    final query = database.select(database.inventoryMovements)
      ..where((movement) => movement.productId.equals(productId))
      ..where((movement) => movement.businessId.equals(businessId))
      ..orderBy([(movement) => OrderingTerm.desc(movement.createdAt)]);

    final rows = await query.get();

    return rows
        .map(
          (row) => domain.InventoryMovement(
            id: row.id,
            productId: row.productId!,
            productNameSnapshot: row.productNameSnapshot,
            movementType: row.movementType,
            quantityDelta: row.quantityDelta,
            referenceType: row.referenceType,
            referenceId: row.referenceId,
            note: row.note,
            createdAt: row.createdAt,
          ),
        )
        .toList();
  }

  @override
  Future<void> recordMovement(domain.InventoryMovement movement) async {
    await database.transaction(() async {
      final productQuery = database.select(database.products)
        ..where((product) => product.id.equals(movement.productId))
        ..where((product) => product.businessId.equals(businessId));

      final product = await productQuery.getSingleOrNull();

      if (product == null) {
        throw StateError('Product does not exist.');
      }

      if (!product.trackInventory) {
        throw StateError('Inventory tracking is disabled for this product.');
      }

      if (movement.quantityDelta == 0) {
        throw ArgumentError('Movement quantity cannot be zero.');
      }

      final currentStock = await getStockQuantity(movement.productId);
      final resultingStock = currentStock + movement.quantityDelta;

      if (resultingStock < 0) {
        throw StateError('Insufficient stock for this movement.');
      }

      await database
          .into(database.inventoryMovements)
          .insert(
            InventoryMovementsCompanion.insert(
              businessId: Value(businessId),
              id: movement.id,
              productId: Value(movement.productId),
              productNameSnapshot: movement.productNameSnapshot,
              movementType: movement.movementType,
              quantityDelta: movement.quantityDelta,
              referenceType: Value(movement.referenceType),
              referenceId: Value(movement.referenceId),
              note: Value(movement.note),
              createdAt: movement.createdAt,
            ),
          );
    });
  }
}
