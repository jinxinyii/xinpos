import 'package:drift/drift.dart';

class Expenses extends Table {
  TextColumn get businessId => text().withDefault(const Constant('default'))();

  TextColumn get id => text()();

  TextColumn get description => text()();

  TextColumn get category => text()();

  IntColumn get amountCentavos => integer()();

  TextColumn get paymentMethod => text().nullable()();

  IntColumn get expenseDate => integer()();

  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
