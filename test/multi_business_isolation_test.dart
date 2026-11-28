import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xinpos/core/database/app_database.dart';
import 'package:xinpos/features/products/data/repositories/category_repository_impl.dart';
import 'package:xinpos/features/products/data/repositories/product_repository_impl.dart';
import 'package:xinpos/features/products/domain/entities/category.dart'
    as domain_category;
import 'package:xinpos/features/products/domain/entities/product.dart'
    as domain_product;
import 'package:xinpos/features/products/domain/services/product_creation_service.dart';
import 'package:xinpos/features/synchronization/data/repositories/sync_outbox_repository.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test(
    'a category cannot be moved into another business by an upsert',
    () async {
      final primaryCategories = CategoryRepositoryImpl(database, 'default');
      final secondCategories = CategoryRepositoryImpl(
        database,
        'second-business',
      );
      final category = _category('category-1', 'Beverages');

      await primaryCategories.saveCategory(category);

      await expectLater(
        secondCategories.saveCategory(category),
        throwsA(isA<StateError>()),
      );

      expect(await primaryCategories.getCategoryById(category.id), isNotNull);
      expect(await secondCategories.getCategoryById(category.id), isNull);
    },
  );

  test(
    'a product cannot use a category or identifier from another business',
    () async {
      final primaryCategories = CategoryRepositoryImpl(database, 'default');
      final primaryProducts = ProductRepositoryImpl(database, 'default');
      final secondProducts = ProductRepositoryImpl(database, 'second-business');
      final category = _category('category-1', 'Beverages');
      final product = _product('product-1', category.id, 'Iced tea');

      await primaryCategories.saveCategory(category);
      await primaryProducts.saveProduct(product);

      await expectLater(
        secondProducts.saveProduct(product),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        secondProducts.saveProduct(
          _product('product-2', category.id, 'Lemonade'),
        ),
        throwsA(isA<StateError>()),
      );

      expect(await primaryProducts.getProductById(product.id), isNotNull);
      expect(await secondProducts.getProductById(product.id), isNull);
      expect(await secondProducts.getProductById('product-2'), isNull);
    },
  );

  test('the same SKU can be used by different businesses', () async {
    final primary = ProductCreationService(
      database: database,
      businessId: 'default',
    );
    final second = ProductCreationService(
      database: database,
      businessId: 'second-business',
    );

    final firstProductId = await primary.createProduct(
      name: 'Iced tea',
      sku: 'TEA-001',
      costPriceCentavos: 1000,
      sellingPriceCentavos: 1500,
      reorderLevel: 0,
      trackInventory: true,
    );
    final secondProductId = await second.createProduct(
      name: 'Iced tea',
      sku: 'TEA-001',
      costPriceCentavos: 1000,
      sellingPriceCentavos: 1500,
      reorderLevel: 0,
      trackInventory: true,
    );

    expect(firstProductId, isNot(secondProductId));
    expect(
      (await ProductRepositoryImpl(
        database,
        'default',
      ).getProducts()).single.sku,
      'TEA-001',
    );
    expect(
      (await ProductRepositoryImpl(
        database,
        'second-business',
      ).getProducts()).single.sku,
      'TEA-001',
    );
    final outbox = SyncOutboxRepository(database);
    final pending = await outbox.pending();
    expect(pending, hasLength(2));

    await outbox.recordFailure(pending.first.id, StateError('Connection lost'));
    final failedAttempt = await (database.select(
      database.syncOutbox,
    )..where((row) => row.id.equals(pending.first.id))).getSingle();
    expect(failedAttempt.attempts, 1);

    await outbox.markSynced(pending.first.id);
    expect(await outbox.pending(), hasLength(1));
  });
}

domain_category.Category _category(String id, String name) =>
    domain_category.Category(
      id: id,
      name: name,
      isActive: true,
      createdAt: 1,
      updatedAt: 1,
    );

domain_product.Product _product(String id, String categoryId, String name) =>
    domain_product.Product(
      id: id,
      categoryId: categoryId,
      name: name,
      costPriceCentavos: 1000,
      sellingPriceCentavos: 1500,
      reorderLevel: 0,
      trackInventory: true,
      isActive: true,
      createdAt: 1,
      updatedAt: 1,
    );
