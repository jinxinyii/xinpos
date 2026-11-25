import 'package:drift/drift.dart';

import 'sales_table.dart';

class QueueEntries extends Table {
  TextColumn get businessId => text().withDefault(const Constant('default'))();

  TextColumn get id => text()();

  TextColumn get saleId =>
      text().unique().references(Sales, #id, onDelete: KeyAction.cascade)();

  TextColumn get queueDate => text()();

  IntColumn get queueNumber => integer()();

  TextColumn get queueCode => text()();

  TextColumn get status => text().withDefault(const Constant('waiting'))();

  TextColumn get preparationStatus =>
      text().withDefault(const Constant('preparing'))();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {businessId, queueDate, queueNumber},
  ];
}
