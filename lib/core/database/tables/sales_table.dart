import 'package:drift/drift.dart';

class Sales extends Table {
  TextColumn get id => text()();

  TextColumn get receiptNumber => text().unique()();

  TextColumn get deviceId => text().nullable()();

  TextColumn get status => text().withDefault(const Constant('completed'))();

  IntColumn get subtotalCentavos => integer()();

  IntColumn get discountCentavos => integer().withDefault(const Constant(0))();

  IntColumn get totalCentavos => integer()();

  IntColumn get soldAt => integer()();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
