import 'package:drift/drift.dart';

import 'sales_table.dart';
import 'products_table.dart';

class SaleItems extends Table {
  TextColumn get id => text()();

  TextColumn get saleId =>
      text().references(Sales, #id, onDelete: KeyAction.cascade)();

  TextColumn get productId => text().nullable().references(
    Products,
    #id,
    onDelete: KeyAction.setNull,
  )();

  TextColumn get productName => text()();

  TextColumn get sku => text().nullable()();

  IntColumn get quantity => integer()();

  IntColumn get unitPriceCentavos => integer()();

  IntColumn get unitCostCentavos => integer()();

  IntColumn get lineTotalCentavos => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
