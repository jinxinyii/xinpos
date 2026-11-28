import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../synchronization/data/repositories/sync_outbox_repository.dart';
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
    await database.transaction(() async {
      await _ensureCategoryBelongsToBusiness(product.categoryId);

      final existing = await (database.select(
        database.products,
      )..where((row) => row.id.equals(product.id))).getSingleOrNull();

      if (existing != null && existing.businessId != businessId) {
        throw StateError('Product belongs to a different business.');
      }

      final values = ProductsCompanion(
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
      );

      if (existing == null) {
        await database
            .into(database.products)
            .insert(
              values.copyWith(
                businessId: Value(businessId),
                id: Value(product.id),
              ),
            );
      } else {
        await (database.update(database.products)..where(
              (row) =>
                  row.id.equals(product.id) & row.businessId.equals(businessId),
            ))
            .write(values);
      }

      await SyncOutboxRepository(database).enqueue(
        entityType: 'product',
        entityId: product.id,
        operation: existing == null ? 'create' : 'upsert',
        payload: {
          'id': product.id,
          'businessId': businessId,
          'categoryId': product.categoryId,
          'name': product.name,
          'sku': product.sku,
          'description': product.description,
          'costPriceCentavos': product.costPriceCentavos,
          'sellingPriceCentavos': product.sellingPriceCentavos,
          'reorderLevel': product.reorderLevel,
          'trackInventory': product.trackInventory,
          'isActive': product.isActive,
          'createdAt': product.createdAt,
          'updatedAt': product.updatedAt,
        },
      );
    });
  }

  Future<void> _ensureCategoryBelongsToBusiness(String? categoryId) async {
    if (categoryId == null) return;

    final category =
        await (database.select(database.categories)
              ..where((row) => row.id.equals(categoryId))
              ..where((row) => row.businessId.equals(businessId)))
            .getSingleOrNull();

    if (category == null) {
      throw StateError(
        'Category belongs to a different business or is missing.',
      );
    }
  }

  @override
  Future<void> archiveProduct(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated =
        await (database.update(database.products)
              ..where((product) => product.id.equals(id))
              ..where((product) => product.businessId.equals(businessId)))
            .write(
              ProductsCompanion(
                isActive: const Value(false),
                updatedAt: Value(now),
              ),
            );
    if (updated == 0) return;

    await SyncOutboxRepository(database).enqueue(
      entityType: 'product',
      entityId: id,
      operation: 'upsert',
      payload: {
        'id': id,
        'businessId': businessId,
        'isActive': false,
        'updatedAt': now,
      },
    );
  }
}
