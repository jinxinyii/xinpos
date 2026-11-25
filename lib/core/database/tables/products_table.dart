import 'package:drift/drift.dart';

import 'categories_table.dart';

class Products extends Table {
  TextColumn get businessId => text().withDefault(const Constant('default'))();

  TextColumn get id => text()();

  TextColumn get categoryId => text().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.setNull,
  )();

  TextColumn get name => text().withLength(min: 1, max: 150)();

  TextColumn get sku => text().nullable().unique()();

  TextColumn get description => text().nullable()();

  IntColumn get costPriceCentavos => integer()();

  IntColumn get sellingPriceCentavos => integer()();

  IntColumn get reorderLevel => integer().withDefault(const Constant(0))();

  BoolColumn get trackInventory =>
      boolean().withDefault(const Constant(true))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
