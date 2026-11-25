import 'package:drift/drift.dart';

class BusinessDatasets extends Table {
  TextColumn get id => text()();

  TextColumn get name => text().withLength(min: 1, max: 80).unique()();

  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
