import 'package:drift/drift.dart';

import 'sales_table.dart';

class Payments extends Table {
  TextColumn get id => text()();

  TextColumn get saleId =>
      text().references(Sales, #id, onDelete: KeyAction.cascade)();

  TextColumn get method => text()();

  IntColumn get amountCentavos => integer()();

  IntColumn get amountTenderedCentavos => integer().nullable()();

  TextColumn get referenceNumber => text().nullable()();

  IntColumn get paidAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
