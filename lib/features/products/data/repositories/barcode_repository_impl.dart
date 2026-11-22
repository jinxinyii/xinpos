import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/product.dart' as domain;
import '../../domain/entities/product_barcode.dart' as domain;
import '../../domain/repositories/barcode_repository.dart';

class BarcodeRepositoryImpl implements BarcodeRepository {
  final AppDatabase database;

  BarcodeRepositoryImpl(this.database);

  @override
  Future<List<domain.ProductBarcode>> getBarcodes(String productId) async {
    final query = database.select(database.productBarcodes)
      ..where((barcode) => barcode.productId.equals(productId))
      ..orderBy([(barcode) => OrderingTerm.asc(barcode.createdAt)]);

    final rows = await query.get();

    return rows
        .map(
          (row) => domain.ProductBarcode(
            id: row.id,
            productId: row.productId,
            barcode: row.barcode,
            createdAt: row.createdAt,
          ),
        )
        .toList();
  }

  @override
  Future<domain.Product?> getProductByBarcode(String barcode) async {
    final normalizedBarcode = barcode.trim();

    if (normalizedBarcode.isEmpty) return null;

    final barcodeRow =
        await (database.select(database.productBarcodes)
              ..where((table) => table.barcode.equals(normalizedBarcode)))
            .getSingleOrNull();

    if (barcodeRow == null) return null;

    final productRow =
        await (database.select(database.products)..where(
              (table) =>
                  table.id.equals(barcodeRow.productId) &
                  table.isActive.equals(true),
            ))
            .getSingleOrNull();

    if (productRow == null) return null;

    return domain.Product(
      id: productRow.id,
      categoryId: productRow.categoryId,
      name: productRow.name,
      sku: productRow.sku,
      description: productRow.description,
      costPriceCentavos: productRow.costPriceCentavos,
      sellingPriceCentavos: productRow.sellingPriceCentavos,
      reorderLevel: productRow.reorderLevel,
      trackInventory: productRow.trackInventory,
      isActive: productRow.isActive,
      createdAt: productRow.createdAt,
      updatedAt: productRow.updatedAt,
    );
  }

  @override
  Future<void> addBarcode(domain.ProductBarcode barcode) async {
    await database.transaction(() async {
      final product =
          await (database.select(database.products)..where(
                (table) =>
                    table.id.equals(barcode.productId) &
                    table.isActive.equals(true),
              ))
              .getSingleOrNull();

      if (product == null) {
        throw StateError('Active product could not be found.');
      }

      await database
          .into(database.productBarcodes)
          .insert(
            ProductBarcodesCompanion.insert(
              id: barcode.id,
              productId: barcode.productId,
              barcode: barcode.barcode,
              createdAt: barcode.createdAt,
            ),
          );
    });
  }

  @override
  Future<void> deleteBarcode(String barcodeId) async {
    await (database.delete(
      database.productBarcodes,
    )..where((table) => table.id.equals(barcodeId))).go();
  }
}
