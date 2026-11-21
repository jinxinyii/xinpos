import 'package:drift/drift.dart';

class SyncConflicts extends Table {
  TextColumn get id => text()();

  TextColumn get entityType => text()();

  TextColumn get entityId => text()();

  TextColumn get conflictType => text()();

  TextColumn get localDataJson => text()();

  TextColumn get serverDataJson => text()();

  TextColumn get resolution => text().nullable()();

  IntColumn get detectedAt => integer()();

  IntColumn get resolvedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
