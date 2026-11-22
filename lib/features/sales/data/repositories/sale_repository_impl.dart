import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/sale_checkout_item.dart';
import '../../domain/entities/sale_checkout_result.dart';
import '../../domain/repositories/sale_repository.dart';

class SaleRepositoryImpl implements SaleRepository {
  final AppDatabase database;

  SaleRepositoryImpl(this.database);

  static const _uuid = Uuid();

  @override
  Future<SaleCheckoutResult> checkout({
    required List<SaleCheckoutItem> items,
    required String paymentMethod,
    required int amountTenderedCentavos,
    String? referenceNumber,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('The cart is empty.');
    }

    final method = paymentMethod.trim().toLowerCase();

    if (method != 'cash' && method != 'gcash') {
      throw ArgumentError('Unsupported payment method.');
    }

    if (amountTenderedCentavos <= 0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }

    final quantities = <String, int>{};

    for (final item in items) {
      if (item.productId.trim().isEmpty || item.quantity <= 0) {
        throw ArgumentError('Invalid checkout item.');
      }

      quantities.update(
        item.productId,
        (quantity) => quantity + item.quantity,
        ifAbsent: () => item.quantity,
      );
    }

    return database.transaction(() async {
      final productsQuery = database.select(database.products)
        ..where((product) => product.id.isIn(quantities.keys));

      final products = await productsQuery.get();
      final productsById = {
        for (final product in products) product.id: product,
      };

      if (productsById.length != quantities.length) {
        throw StateError('One or more products no longer exist.');
      }

      var subtotalCentavos = 0;

      for (final entry in quantities.entries) {
        final product = productsById[entry.key]!;

        if (!product.isActive) {
          throw StateError('${product.name} is no longer active.');
        }

        subtotalCentavos += product.sellingPriceCentavos * entry.value;

        if (product.trackInventory) {
          final stockResult = await database
              .customSelect(
                'SELECT COALESCE(SUM(quantity_delta), 0) AS stock '
                'FROM inventory_movements WHERE product_id = ?',
                variables: [Variable.withString(product.id)],
                readsFrom: {database.inventoryMovements},
              )
              .getSingle();

          final currentStock = stockResult.read<int>('stock');

          if (currentStock < entry.value) {
            throw StateError(
              'Insufficient stock for ${product.name}. '
              'Available: $currentStock, requested: ${entry.value}.',
            );
          }
        }
      }

      final totalCentavos = subtotalCentavos;

      if (method == 'cash' && amountTenderedCentavos < totalCentavos) {
        throw StateError('Cash received is insufficient.');
      }

      if (method == 'gcash' && amountTenderedCentavos != totalCentavos) {
        throw StateError('GCash payment must equal the sale total.');
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final saleId = _uuid.v4();
      final receiptNumber =
          'XPOS-${DateTime.now().toString().replaceAll(RegExp(r'[^0-9]'), '').substring(0, 14)}-${_uuid.v4().substring(0, 6).toUpperCase()}';

      await database
          .into(database.sales)
          .insert(
            SalesCompanion.insert(
              id: saleId,
              receiptNumber: receiptNumber,
              subtotalCentavos: subtotalCentavos,
              totalCentavos: totalCentavos,
              soldAt: now,
              createdAt: now,
              updatedAt: now,
            ),
          );

      for (final entry in quantities.entries) {
        final product = productsById[entry.key]!;
        final quantity = entry.value;
        final lineTotal = product.sellingPriceCentavos * quantity;

        await database
            .into(database.saleItems)
            .insert(
              SaleItemsCompanion.insert(
                id: _uuid.v4(),
                saleId: saleId,
                productId: Value(product.id),
                productName: product.name,
                sku: Value(product.sku),
                quantity: quantity,
                unitPriceCentavos: product.sellingPriceCentavos,
                unitCostCentavos: product.costPriceCentavos,
                lineTotalCentavos: lineTotal,
              ),
            );

        if (product.trackInventory) {
          await database
              .into(database.inventoryMovements)
              .insert(
                InventoryMovementsCompanion.insert(
                  id: _uuid.v4(),
                  productId: Value(product.id),
                  productNameSnapshot: product.name,
                  movementType: 'sale',
                  quantityDelta: -quantity,
                  referenceType: const Value('sale'),
                  referenceId: Value(saleId),
                  note: Value('Sale $receiptNumber'),
                  createdAt: now,
                ),
              );
        }
      }

      final changeCentavos = method == 'cash'
          ? amountTenderedCentavos - totalCentavos
          : 0;

      await database
          .into(database.payments)
          .insert(
            PaymentsCompanion.insert(
              id: _uuid.v4(),
              saleId: saleId,
              method: method,
              amountCentavos: totalCentavos,
              referenceNumber: Value(
                referenceNumber?.trim().isEmpty ?? true
                    ? null
                    : referenceNumber!.trim(),
              ),
              paidAt: now,
            ),
          );

      return SaleCheckoutResult(
        saleId: saleId,
        receiptNumber: receiptNumber,
        subtotalCentavos: subtotalCentavos,
        totalCentavos: totalCentavos,
        changeCentavos: changeCentavos,
      );
    });
  }
}
