import 'package:drift/drift.dart';

import 'products_table.dart';

class InventoryMovements extends Table {
  TextColumn get id => text()();

  TextColumn get productId => text().nullable().references(
    Products,
    #id,
    onDelete: KeyAction.setNull,
  )();

  TextColumn get productNameSnapshot => text()();

  TextColumn get movementType => text()();

  IntColumn get quantityDelta => integer()();

  TextColumn get referenceType => text().nullable()();

  TextColumn get referenceId => text().nullable()();

  TextColumn get note => text().nullable()();

  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
