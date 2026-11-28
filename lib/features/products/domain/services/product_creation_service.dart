import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../synchronization/data/repositories/sync_outbox_repository.dart';

class ProductCreationService {
  final AppDatabase database;
  final String businessId;
  final Uuid uuid;

  ProductCreationService({
    required this.database,
    required this.businessId,
    Uuid? uuid,
  }) : uuid = uuid ?? const Uuid();

  Future<String> createProduct({
    required String name,
    String? sku,
    String? description,
    String? categoryId,
    required int costPriceCentavos,
    required int sellingPriceCentavos,
    required int reorderLevel,
    required bool trackInventory,
    int initialStock = 0,
  }) async {
    final normalizedName = name.trim();
    final normalizedSku = sku?.trim();
    final normalizedDescription = description?.trim();

    if (normalizedName.isEmpty) {
      throw ArgumentError('Product name is required.');
    }

    if (costPriceCentavos < 0 || sellingPriceCentavos < 0) {
      throw ArgumentError('Product prices cannot be negative.');
    }

    if (reorderLevel < 0 || initialStock < 0) {
      throw ArgumentError('Stock quantities cannot be negative.');
    }

    if (!trackInventory && initialStock > 0) {
      throw ArgumentError(
        'Initial stock cannot be entered when inventory tracking is disabled.',
      );
    }

    final productId = uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await database.transaction(() async {
      if (categoryId != null) {
        final category =
            await (database.select(database.categories)
                  ..where((table) => table.id.equals(categoryId))
                  ..where((table) => table.businessId.equals(businessId))
                  ..where((table) => table.isActive.equals(true)))
                .getSingleOrNull();

        if (category == null) {
          throw StateError('Selected category does not exist or is archived.');
        }
      }

      if (normalizedSku != null && normalizedSku.isNotEmpty) {
        final existingSku =
            await (database.select(database.products)
                  ..where((table) => table.sku.equals(normalizedSku))
                  ..where((table) => table.businessId.equals(businessId)))
                .getSingleOrNull();

        if (existingSku != null) {
          throw StateError('This SKU is already assigned to another product.');
        }
      }

      await database
          .into(database.products)
          .insert(
            ProductsCompanion(
              businessId: Value(businessId),
              id: Value(productId),
              categoryId: Value(categoryId),
              name: Value(normalizedName),
              sku: Value(
                normalizedSku == null || normalizedSku.isEmpty
                    ? null
                    : normalizedSku,
              ),
              description: Value(
                normalizedDescription == null || normalizedDescription.isEmpty
                    ? null
                    : normalizedDescription,
              ),
              costPriceCentavos: Value(costPriceCentavos),
              sellingPriceCentavos: Value(sellingPriceCentavos),
              reorderLevel: Value(reorderLevel),
              trackInventory: Value(trackInventory),
              isActive: const Value(true),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await SyncOutboxRepository(database).enqueue(
        entityType: 'product',
        entityId: productId,
        operation: 'upsert',
        payload: {
          'id': productId,
          'businessId': businessId,
          'categoryId': categoryId,
          'name': normalizedName,
          'sku': normalizedSku == null || normalizedSku.isEmpty
              ? null
              : normalizedSku,
          'description':
              normalizedDescription == null || normalizedDescription.isEmpty
              ? null
              : normalizedDescription,
          'costPriceCentavos': costPriceCentavos,
          'sellingPriceCentavos': sellingPriceCentavos,
          'reorderLevel': reorderLevel,
          'trackInventory': trackInventory,
          'isActive': true,
          'createdAt': now,
          'updatedAt': now,
        },
      );

      if (initialStock > 0) {
        final movementId = uuid.v4();
        await database
            .into(database.inventoryMovements)
            .insert(
              InventoryMovementsCompanion.insert(
                businessId: Value(businessId),
                id: movementId,
                productId: Value(productId),
                productNameSnapshot: normalizedName,
                movementType: 'opening_stock',
                quantityDelta: initialStock,
                referenceType: const Value('product'),
                referenceId: Value(productId),
                note: const Value('Initial stock'),
                createdAt: now,
              ),
            );

        await SyncOutboxRepository(database).enqueue(
          entityType: 'inventory_movement',
          entityId: movementId,
          operation: 'create',
          payload: {
            'businessId': businessId,
            'productId': productId,
            'movementType': 'opening_stock',
            'quantityDelta': initialStock,
            'createdAt': now,
          },
        );
      }
    });

    return productId;
  }
}
