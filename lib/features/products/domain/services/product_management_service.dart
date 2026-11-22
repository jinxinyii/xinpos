import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';

class ProductManagementService {
  final AppDatabase database;

  ProductManagementService({required this.database});

  Future<void> updateProduct({
    required String productId,
    required String name,
    String? sku,
    String? description,
    String? categoryId,
    required int costPriceCentavos,
    required int sellingPriceCentavos,
    required int reorderLevel,
    required bool trackInventory,
  }) async {
    final normalizedName = name.trim();
    final normalizedSku = sku?.trim();
    final normalizedDescription = description?.trim();
    final normalizedCategoryId = categoryId?.trim();

    if (normalizedName.isEmpty) {
      throw ArgumentError('Product name is required.');
    }

    if (costPriceCentavos < 0 || sellingPriceCentavos < 0) {
      throw ArgumentError('Product prices cannot be negative.');
    }

    if (reorderLevel < 0) {
      throw ArgumentError('Reorder level cannot be negative.');
    }

    await database.transaction(() async {
      final existingProduct = await (database.select(
        database.products,
      )..where((table) => table.id.equals(productId))).getSingleOrNull();

      if (existingProduct == null) {
        throw StateError('Product could not be found.');
      }

      if (!existingProduct.isActive) {
        throw StateError('Archived products cannot be edited.');
      }

      if (normalizedCategoryId != null && normalizedCategoryId.isNotEmpty) {
        final category =
            await (database.select(database.categories)..where(
                  (table) =>
                      table.id.equals(normalizedCategoryId) &
                      table.isActive.equals(true),
                ))
                .getSingleOrNull();

        if (category == null) {
          throw StateError('Selected category does not exist or is archived.');
        }
      }

      if (normalizedSku != null && normalizedSku.isNotEmpty) {
        final duplicateSku =
            await (database.select(database.products)..where(
                  (table) =>
                      table.sku.equals(normalizedSku) &
                      table.id.isNotValue(productId),
                ))
                .getSingleOrNull();

        if (duplicateSku != null) {
          throw StateError('This SKU is already assigned to another product.');
        }
      }

      if (!trackInventory && existingProduct.trackInventory) {
        final stockExpression = database.inventoryMovements.quantityDelta.sum();

        final stockQuery = database.selectOnly(database.inventoryMovements)
          ..where(database.inventoryMovements.productId.equals(productId));

        stockQuery.addColumns([stockExpression]);

        final stockResult = await stockQuery.getSingle();
        final currentStock = stockResult.read(stockExpression) ?? 0;

        if (currentStock != 0) {
          throw StateError(
            'Inventory tracking cannot be disabled while this product has stock. Adjust its stock to zero first.',
          );
        }
      }

      await (database.update(
        database.products,
      )..where((table) => table.id.equals(productId))).write(
        ProductsCompanion(
          categoryId: Value(
            normalizedCategoryId == null || normalizedCategoryId.isEmpty
                ? null
                : normalizedCategoryId,
          ),
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
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
    });
  }

  Future<void> archiveProduct(String productId) async {
    await database.transaction(() async {
      final product = await (database.select(
        database.products,
      )..where((table) => table.id.equals(productId))).getSingleOrNull();

      if (product == null) {
        throw StateError('Product could not be found.');
      }

      if (!product.isActive) {
        throw StateError('This product is already archived.');
      }

      await (database.update(
        database.products,
      )..where((table) => table.id.equals(productId))).write(
        ProductsCompanion(
          isActive: const Value(false),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
    });
  }
}
