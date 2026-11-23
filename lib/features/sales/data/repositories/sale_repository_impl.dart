import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart' hide QueueEntry;
import '../../domain/entities/queue_entry.dart';
import '../../domain/entities/queue_summary.dart';
import '../../domain/entities/sale_checkout_item.dart';
import '../../domain/entities/sale_checkout_result.dart';
import '../../domain/entities/sale_detail.dart';
import '../../domain/entities/sale_summary.dart';
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

      final queueDate = DateFormat('yyyy-MM-dd')
          .format(DateTime.fromMillisecondsSinceEpoch(now));
      await database.customStatement(
        'INSERT INTO queue_daily_counters (queue_date, last_number) '
        'VALUES (?, (SELECT COALESCE(MAX(queue_number), 0) + 1 '
        'FROM queue_entries WHERE queue_date = ?)) '
        'ON CONFLICT(queue_date) DO UPDATE SET last_number = '
        'MAX(queue_daily_counters.last_number, '
        '(SELECT COALESCE(MAX(queue_number), 0) FROM queue_entries '
        'WHERE queue_date = ?)) + 1',
        [queueDate, queueDate, queueDate],
      );

      final counterRows = await database
          .customSelect(
            'SELECT last_number FROM queue_daily_counters WHERE queue_date = ?',
            variables: [Variable.withString(queueDate)],
            readsFrom: {database.queueDailyCounters},
          )
          .getSingle();
      final queueNumber = counterRows.read<int>('last_number');
      final queueCode = 'A-${queueNumber.toString().padLeft(3, '0')}';

      await database
          .into(database.queueEntries)
          .insert(
            QueueEntriesCompanion.insert(
              id: _uuid.v4(),
              saleId: saleId,
              queueDate: queueDate,
              queueNumber: queueNumber,
              queueCode: queueCode,
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
              amountTenderedCentavos: Value(amountTenderedCentavos),
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
        queueCode: queueCode,
        subtotalCentavos: subtotalCentavos,
        totalCentavos: totalCentavos,
        changeCentavos: changeCentavos,
      );
    });
  }

  @override
  Future<List<SaleSummary>> getSales({String search = ''}) async {
    final normalizedSearch = search.trim();
    final rows = await database
        .customSelect(
          '''
      SELECT
        s.id AS sale_id,
        s.receipt_number,
        s.status,
        s.subtotal_centavos,
        s.discount_centavos,
        s.total_centavos,
        s.sold_at,
        qe.queue_code,
        COUNT(si.id) AS item_count,
        COALESCE(
          (SELECT p.method FROM payments p
           WHERE p.sale_id = s.id
           ORDER BY p.paid_at DESC LIMIT 1),
          ''
        ) AS payment_method
      FROM sales s
      LEFT JOIN sale_items si ON si.sale_id = s.id
      LEFT JOIN queue_entries qe ON qe.sale_id = s.id
      WHERE (? = '' OR s.receipt_number LIKE ?)
      GROUP BY s.id
      ORDER BY s.sold_at DESC
      ''',
          variables: [
            Variable.withString(normalizedSearch),
            Variable.withString('%$normalizedSearch%'),
          ],
          readsFrom: {
            database.sales,
            database.saleItems,
            database.payments,
            database.queueEntries,
          },
        )
        .get();

    return rows.map((row) {
      return SaleSummary(
        id: row.read<String>('sale_id'),
        receiptNumber: row.read<String>('receipt_number'),
        queueCode: row.readNullable<String>('queue_code'),
        status: row.read<String>('status'),
        subtotalCentavos: row.read<int>('subtotal_centavos'),
        discountCentavos: row.read<int>('discount_centavos'),
        totalCentavos: row.read<int>('total_centavos'),
        soldAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('sold_at')),
        itemCount: row.read<int>('item_count'),
        paymentMethod: row.read<String>('payment_method'),
      );
    }).toList();
  }

  @override
  Future<SaleDetail?> getSaleDetails(String saleId) async {
    final saleRows = await database
        .customSelect(
          '''
      SELECT s.id, s.receipt_number, s.status, s.subtotal_centavos,
             s.discount_centavos, s.total_centavos, s.sold_at,
             qe.queue_code
      FROM sales s
      LEFT JOIN queue_entries qe ON qe.sale_id = s.id
      WHERE s.id = ?
      LIMIT 1
      ''',
          variables: [Variable.withString(saleId)],
          readsFrom: {database.sales},
        )
        .get();

    if (saleRows.isEmpty) return null;

    final sale = saleRows.first;

    final itemRows = await database
        .customSelect(
          '''
      SELECT product_name, sku, quantity, unit_price_centavos,
             unit_cost_centavos, line_total_centavos
      FROM sale_items
      WHERE sale_id = ?
      ORDER BY rowid ASC
      ''',
          variables: [Variable.withString(saleId)],
          readsFrom: {database.saleItems},
        )
        .get();

    final paymentRows = await database
        .customSelect(
          '''
      SELECT method, amount_centavos, amount_tendered_centavos,
             reference_number, paid_at
      FROM payments
      WHERE sale_id = ?
      ORDER BY paid_at DESC
      LIMIT 1
      ''',
          variables: [Variable.withString(saleId)],
          readsFrom: {database.payments},
        )
        .get();

    final items = itemRows.map((row) {
      return SaleDetailItem(
        productName: row.read<String>('product_name'),
        sku: row.readNullable<String>('sku'),
        quantity: row.read<int>('quantity'),
        unitPriceCentavos: row.read<int>('unit_price_centavos'),
        unitCostCentavos: row.read<int>('unit_cost_centavos'),
        lineTotalCentavos: row.read<int>('line_total_centavos'),
      );
    }).toList();

    SalePaymentDetail? payment;

    if (paymentRows.isNotEmpty) {
      final row = paymentRows.first;
      payment = SalePaymentDetail(
        method: row.read<String>('method'),
        amountCentavos: row.read<int>('amount_centavos'),
        amountTenderedCentavos: row.readNullable<int>(
          'amount_tendered_centavos',
        ),
        referenceNumber: row.readNullable<String>('reference_number'),
        paidAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('paid_at')),
      );
    }

    return SaleDetail(
      id: sale.read<String>('id'),
      receiptNumber: sale.read<String>('receipt_number'),
      queueCode: sale.readNullable<String>('queue_code'),
      status: sale.read<String>('status'),
      subtotalCentavos: sale.read<int>('subtotal_centavos'),
      discountCentavos: sale.read<int>('discount_centavos'),
      totalCentavos: sale.read<int>('total_centavos'),
      soldAt: DateTime.fromMillisecondsSinceEpoch(sale.read<int>('sold_at')),
      items: items,
      payment: payment,
    );
  }

  String _todayQueueDate() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  QueueEntry _queueEntryFromRow(QueryRow row) {
    return QueueEntry(
      id: row.read<String>('id'),
      saleId: row.read<String>('sale_id'),
      queueDate: row.read<String>('queue_date'),
      queueNumber: row.read<int>('queue_number'),
      queueCode: row.read<String>('queue_code'),
      status: row.read<String>('status'),
      preparationStatus: row.read<String>('preparation_status'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('created_at'),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('updated_at'),
      ),
    );
  }

  @override
  Future<List<QueueEntry>> getTodayQueue() async {
    final date = _todayQueueDate();
    final rows = await database
        .customSelect(
          '''
      SELECT id, sale_id, queue_date, queue_number, queue_code,
             status, preparation_status, created_at, updated_at
      FROM queue_entries
      WHERE queue_date = ?
      ORDER BY queue_number ASC
      ''',
          variables: [Variable.withString(date)],
          readsFrom: {database.queueEntries},
        )
        .get();

    return rows.map(_queueEntryFromRow).toList();
  }

  @override
  Future<QueueSummary> getTodayQueueSummary() async {
    final date = _todayQueueDate();
    final row = await database
        .customSelect(
          '''
      SELECT
        SUM(CASE WHEN status = 'waiting' THEN 1 ELSE 0 END) AS waiting,
        SUM(CASE WHEN status = 'serving' THEN 1 ELSE 0 END) AS serving,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed,
        SUM(CASE WHEN status = 'skipped' THEN 1 ELSE 0 END) AS skipped
      FROM queue_entries
      WHERE queue_date = ?
      ''',
          variables: [Variable.withString(date)],
          readsFrom: {database.queueEntries},
        )
        .getSingle();

    return QueueSummary(
      waiting: row.read<int?>('waiting') ?? 0,
      serving: row.read<int?>('serving') ?? 0,
      completed: row.read<int?>('completed') ?? 0,
      skipped: row.read<int?>('skipped') ?? 0,
    );
  }

  @override
  Future<QueueEntry?> callNextQueueEntry() {
    return database.transaction(() async {
      final date = _todayQueueDate();
      final serving =
          await (database.select(database.queueEntries)
                ..where(
                  (entry) =>
                      entry.queueDate.equals(date) &
                      entry.status.equals('serving'),
                )
                ..limit(1))
              .getSingleOrNull();

      if (serving != null) {
        throw StateError(
          'Complete or skip ${serving.queueCode} before calling the next customer.',
        );
      }

      final next =
          await (database.select(database.queueEntries)
                ..where(
                  (entry) =>
                      entry.queueDate.equals(date) &
                      entry.status.equals('waiting'),
                )
                ..orderBy([(entry) => OrderingTerm.asc(entry.queueNumber)])
                ..limit(1))
              .getSingleOrNull();

      if (next == null) return null;

      final now = DateTime.now().millisecondsSinceEpoch;
      await (database.update(
        database.queueEntries,
      )..where((entry) => entry.id.equals(next.id))).write(
        QueueEntriesCompanion(
          status: const Value('serving'),
          updatedAt: Value(now),
        ),
      );

      return QueueEntry(
        id: next.id,
        saleId: next.saleId,
        queueDate: next.queueDate,
        queueNumber: next.queueNumber,
        queueCode: next.queueCode,
        status: 'serving',
        preparationStatus: next.preparationStatus,
        createdAt: DateTime.fromMillisecondsSinceEpoch(next.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      );
    });
  }

  @override
  Future<QueueEntry?> callNextReadyQueueEntry() {
    return database.transaction(() async {
      final date = _todayQueueDate();
      final serving =
          await (database.select(database.queueEntries)
                ..where(
                  (entry) =>
                      entry.queueDate.equals(date) &
                      entry.status.equals('serving'),
                )
                ..limit(1))
              .getSingleOrNull();

      if (serving != null) {
        throw StateError(
          'Complete or skip ${serving.queueCode} before calling another customer.',
        );
      }

      final next =
          await (database.select(database.queueEntries)
                ..where(
                  (entry) =>
                      entry.queueDate.equals(date) &
                      entry.status.equals('waiting') &
                      entry.preparationStatus.equals('ready'),
                )
                ..orderBy([(entry) => OrderingTerm.asc(entry.queueNumber)])
                ..limit(1))
              .getSingleOrNull();

      if (next == null) return null;

      final now = DateTime.now().millisecondsSinceEpoch;
      await (database.update(
        database.queueEntries,
      )..where((entry) => entry.id.equals(next.id))).write(
        QueueEntriesCompanion(
          status: const Value('serving'),
          updatedAt: Value(now),
        ),
      );

      return QueueEntry(
        id: next.id,
        saleId: next.saleId,
        queueDate: next.queueDate,
        queueNumber: next.queueNumber,
        queueCode: next.queueCode,
        status: 'serving',
        preparationStatus: next.preparationStatus,
        createdAt: DateTime.fromMillisecondsSinceEpoch(next.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      );
    });
  }

  @override
  Future<void> markQueueEntryReady(String queueEntryId) async {
    await _updateQueuePreparationStatus(queueEntryId, 'ready');
  }

  @override
  Future<void> markQueueEntryPreparing(String queueEntryId) async {
    await _updateQueuePreparationStatus(queueEntryId, 'preparing');
  }

  Future<void> _updateQueuePreparationStatus(
    String queueEntryId,
    String preparationStatus,
  ) async {
    final entry =
        await (database.select(database.queueEntries)
              ..where((row) => row.id.equals(queueEntryId))
              ..limit(1))
            .getSingleOrNull();

    if (entry == null) throw StateError('Queue entry was not found.');
    if (entry.status != 'waiting') {
      throw StateError(
        'Only waiting queue entries can change preparation status.',
      );
    }

    await (database.update(
      database.queueEntries,
    )..where((row) => row.id.equals(queueEntryId))).write(
      QueueEntriesCompanion(
        preparationStatus: Value(preparationStatus),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  @override
  Future<void> completeQueueEntry(String queueEntryId) async {
    await _updateQueueStatus(queueEntryId, 'completed', allowedFrom: 'serving');
  }

  @override
  Future<void> skipQueueEntry(String queueEntryId) async {
    await database.transaction(() async {
      final entry =
          await (database.select(database.queueEntries)
                ..where((row) => row.id.equals(queueEntryId))
                ..limit(1))
              .getSingleOrNull();

      if (entry == null) throw StateError('Queue entry was not found.');
      if (entry.status != 'waiting' && entry.status != 'serving') {
        throw StateError('Only waiting or serving entries can be skipped.');
      }

      await (database.update(
        database.queueEntries,
      )..where((row) => row.id.equals(queueEntryId))).write(
        QueueEntriesCompanion(
          status: const Value('skipped'),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
    });
  }

  Future<void> _updateQueueStatus(
    String queueEntryId,
    String newStatus, {
    required String allowedFrom,
  }) async {
    final entry =
        await (database.select(database.queueEntries)
              ..where((row) => row.id.equals(queueEntryId))
              ..limit(1))
            .getSingleOrNull();

    if (entry == null) throw StateError('Queue entry was not found.');
    if (entry.status != allowedFrom) {
      throw StateError('This queue entry can no longer be updated.');
    }

    await (database.update(
      database.queueEntries,
    )..where((row) => row.id.equals(queueEntryId))).write(
      QueueEntriesCompanion(
        status: Value(newStatus),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }
}
