import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/product.dart' as domain;
import '../../domain/repositories/product_repository.dart';

class ProductRepositoryImpl implements ProductRepository {
  final AppDatabase database;

  ProductRepositoryImpl(this.database);

  @override
  Future<List<domain.Product>> getProducts({
    String? search,
    String? categoryId,
    bool activeOnly = true,
  }) async {
    final query = database.select(database.products);

    query.where((product) {
      Expression<bool> condition = const Constant(true);

      if (activeOnly) {
        condition = condition & product.isActive.equals(true);
      }

      if (categoryId != null) {
        condition = condition & product.categoryId.equals(categoryId);
      }

      final term = search?.trim();

      if (term != null && term.isNotEmpty) {
        condition =
            condition &
            (product.name.contains(term) | product.sku.contains(term));
      }

      return condition;
    });

    query.orderBy([(product) => OrderingTerm.asc(product.name)]);

    final rows = await query.get();

    return rows
        .map(
          (row) => domain.Product(
            id: row.id,
            categoryId: row.categoryId,
            name: row.name,
            sku: row.sku,
            description: row.description,
            costPriceCentavos: row.costPriceCentavos,
            sellingPriceCentavos: row.sellingPriceCentavos,
            reorderLevel: row.reorderLevel,
            trackInventory: row.trackInventory,
            isActive: row.isActive,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
          ),
        )
        .toList();
  }

  @override
  Future<domain.Product?> getProductById(String id) async {
    final query = database.select(database.products)
      ..where((product) => product.id.equals(id));

    final row = await query.getSingleOrNull();

    if (row == null) return null;

    return domain.Product(
      id: row.id,
      categoryId: row.categoryId,
      name: row.name,
      sku: row.sku,
      description: row.description,
      costPriceCentavos: row.costPriceCentavos,
      sellingPriceCentavos: row.sellingPriceCentavos,
      reorderLevel: row.reorderLevel,
      trackInventory: row.trackInventory,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  @override
  Future<void> saveProduct(domain.Product product) async {
    await database
        .into(database.products)
        .insertOnConflictUpdate(
          ProductsCompanion(
            id: Value(product.id),
            categoryId: Value(product.categoryId),
            name: Value(product.name),
            sku: Value(product.sku),
            description: Value(product.description),
            costPriceCentavos: Value(product.costPriceCentavos),
            sellingPriceCentavos: Value(product.sellingPriceCentavos),
            reorderLevel: Value(product.reorderLevel),
            trackInventory: Value(product.trackInventory),
            isActive: Value(product.isActive),
            createdAt: Value(product.createdAt),
            updatedAt: Value(product.updatedAt),
          ),
        );
  }

  @override
  Future<void> archiveProduct(String id) async {
    await (database.update(
      database.products,
    )..where((product) => product.id.equals(id))).write(
      ProductsCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }
}
