import 'package:drift/drift.dart';

import 'products_table.dart';

class ProductBarcodes extends Table {
  TextColumn get id => text()();

  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.cascade)();

  TextColumn get barcode => text().unique()();

  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
