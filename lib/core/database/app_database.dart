import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/business_datasets_table.dart';
import 'tables/categories_table.dart';
import 'tables/products_table.dart';
import 'tables/product_barcodes_table.dart';
import 'tables/sales_table.dart';
import 'tables/sale_items_table.dart';
import 'tables/payments_table.dart';
import 'tables/inventory_movements_table.dart';
import 'tables/expenses_table.dart';
import 'tables/sync_outbox_table.dart';
import 'tables/sync_state_table.dart';
import 'tables/sync_conflicts_table.dart';
import 'tables/queue_daily_counters_table.dart';
import 'tables/queue_entries_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    BusinessDatasets,
    Categories,
    Products,
    ProductBarcodes,
    Sales,
    SaleItems,
    Payments,
    InventoryMovements,
    Expenses,
    SyncOutbox,
    SyncState,
    SyncConflicts,
    QueueDailyCounters,
    QueueEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'xinpos_db'));

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      final now = DateTime.now().millisecondsSinceEpoch;
      await into(businessDatasets).insert(
        BusinessDatasetsCompanion.insert(
          id: 'default',
          name: 'Default Business',
          createdAt: now,
          updatedAt: now,
        ),
      );
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(sales);
        await m.createTable(saleItems);
        await m.createTable(payments);
        await m.createTable(inventoryMovements);
        await m.createTable(expenses);
        await m.createTable(syncOutbox);
        await m.createTable(syncState);
        await m.createTable(syncConflicts);
      }
      if (from < 3) {
        await m.createTable(queueDailyCounters);
        await m.createTable(queueEntries);
      }
      if (from < 4) {
        await m.addColumn(queueEntries, queueEntries.preparationStatus);
      }
      if (from < 5) {
        await m.addColumn(payments, payments.amountTenderedCentavos);
      }
      if (from < 6) {
        await customStatement(
          'CREATE TABLE queue_entries_new ('
          'id TEXT NOT NULL PRIMARY KEY, '
          'sale_id TEXT NOT NULL UNIQUE REFERENCES sales(id) ON DELETE CASCADE, '
          'queue_date TEXT NOT NULL, '
          'queue_number INTEGER NOT NULL, '
          'queue_code TEXT NOT NULL, '
          'status TEXT NOT NULL DEFAULT \'waiting\', '
          'preparation_status TEXT NOT NULL DEFAULT \'preparing\', '
          'created_at INTEGER NOT NULL, '
          'updated_at INTEGER NOT NULL, '
          'UNIQUE(queue_date, queue_number)'
          ')',
        );
        await customStatement(
          'INSERT INTO queue_entries_new '
          '(id, sale_id, queue_date, queue_number, queue_code, status, '
          'preparation_status, created_at, updated_at) '
          'SELECT id, sale_id, queue_date, queue_number, queue_code, status, '
          'preparation_status, created_at, updated_at FROM queue_entries',
        );
        await customStatement('DROP TABLE queue_entries');
        await customStatement(
          'ALTER TABLE queue_entries_new RENAME TO queue_entries',
        );
      }
      if (from < 7) {
        final now = DateTime.now().millisecondsSinceEpoch;
        await m.createTable(businessDatasets);
        await into(businessDatasets).insert(
          BusinessDatasetsCompanion.insert(
            id: 'default',
            name: 'Default Business',
            createdAt: now,
            updatedAt: now,
          ),
        );

        await m.addColumn(categories, categories.businessId);
        await m.addColumn(products, products.businessId);
        await m.addColumn(sales, sales.businessId);
        await m.addColumn(saleItems, saleItems.businessId);
        await m.addColumn(payments, payments.businessId);
        await m.addColumn(inventoryMovements, inventoryMovements.businessId);
        await m.addColumn(expenses, expenses.businessId);
        await m.addColumn(queueEntries, queueEntries.businessId);

        await customStatement(
          'CREATE TABLE queue_daily_counters_new ('
          'business_id TEXT NOT NULL DEFAULT \'default\', '
          'queue_date TEXT NOT NULL, '
          'last_number INTEGER NOT NULL, '
          'PRIMARY KEY (business_id, queue_date)'
          ')',
        );
        await customStatement(
          'INSERT INTO queue_daily_counters_new '
          '(business_id, queue_date, last_number) '
          'SELECT \'default\', queue_date, last_number '
          'FROM queue_daily_counters',
        );
        await customStatement('DROP TABLE queue_daily_counters');
        await customStatement(
          'ALTER TABLE queue_daily_counters_new RENAME TO queue_daily_counters',
        );

        await customStatement(
          'CREATE TABLE queue_entries_business_new ('
          'id TEXT NOT NULL PRIMARY KEY, '
          'sale_id TEXT NOT NULL UNIQUE REFERENCES sales(id) ON DELETE CASCADE, '
          'business_id TEXT NOT NULL DEFAULT \'default\', '
          'queue_date TEXT NOT NULL, '
          'queue_number INTEGER NOT NULL, '
          'queue_code TEXT NOT NULL, '
          'status TEXT NOT NULL DEFAULT \'waiting\', '
          'preparation_status TEXT NOT NULL DEFAULT \'preparing\', '
          'created_at INTEGER NOT NULL, '
          'updated_at INTEGER NOT NULL, '
          'UNIQUE(business_id, queue_date, queue_number)'
          ')',
        );
        await customStatement(
          'INSERT INTO queue_entries_business_new '
          '(id, sale_id, business_id, queue_date, queue_number, queue_code, '
          'status, preparation_status, created_at, updated_at) '
          'SELECT id, sale_id, \'default\', queue_date, queue_number, queue_code, '
          'status, preparation_status, created_at, updated_at '
          'FROM queue_entries',
        );
        await customStatement('DROP TABLE queue_entries');
        await customStatement(
          'ALTER TABLE queue_entries_business_new RENAME TO queue_entries',
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
