import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'xinpos_db'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
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
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
