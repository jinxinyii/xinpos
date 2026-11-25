import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/product.dart' as domain;
import '../../domain/repositories/product_repository.dart';

class ProductRepositoryImpl implements ProductRepository {
  final AppDatabase database;

  final String businessId;

  ProductRepositoryImpl(this.database, this.businessId);

  @override
  Future<List<domain.Product>> getProducts({
    String? search,
    String? categoryId,
    bool activeOnly = true,
  }) async {
    final query = database.select(database.products)
      ..where((product) => product.businessId.equals(businessId));

    if (activeOnly) {
      query.where((product) => product.isActive.equals(true));
    }

    if (categoryId != null) {
      query.where((product) => product.categoryId.equals(categoryId));
    }

    final term = search?.trim();

    query.orderBy([(product) => OrderingTerm.asc(product.name)]);

    final rows = await query.get();

    final filteredRows = term == null || term.isEmpty
        ? rows
        : rows
              .where(
                (row) =>
                    row.name.toLowerCase().contains(term.toLowerCase()) ||
                    (row.sku?.toLowerCase().contains(term.toLowerCase()) ??
                        false),
              )
              .toList();

    return filteredRows
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
      ..where((product) => product.id.equals(id))
      ..where((product) => product.businessId.equals(businessId));

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
            businessId: Value(businessId),
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
    await (database.update(database.products)
          ..where((product) => product.id.equals(id))
          ..where((product) => product.businessId.equals(businessId)))
        .write(
          ProductsCompanion(
            isActive: const Value(false),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
  }
}
