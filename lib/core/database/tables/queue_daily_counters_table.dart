import 'package:drift/drift.dart';

class QueueDailyCounters extends Table {
  TextColumn get businessId => text().withDefault(const Constant('default'))();

  TextColumn get queueDate => text()();

  IntColumn get lastNumber => integer()();

  @override
  Set<Column> get primaryKey => {businessId, queueDate};
}
