import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/business_expense.dart';

class ExpenseRepository {
  final AppDatabase database;

  ExpenseRepository(this.database);

  static const _uuid = Uuid();

  Future<List<BusinessExpense>> getExpenses() async {
    final query = database.select(database.expenses)
      ..orderBy([
        (expense) => OrderingTerm(
          expression: expense.expenseDate,
          mode: OrderingMode.desc,
        ),
        (expense) => OrderingTerm(
          expression: expense.createdAt,
          mode: OrderingMode.desc,
        ),
      ]);

    final rows = await query.get();

    return rows.map((row) {
      return BusinessExpense(
        id: row.id,
        description: row.description,
        category: row.category,
        amountCentavos: row.amountCentavos,
        paymentMethod: row.paymentMethod,
        expenseDate: DateTime.fromMillisecondsSinceEpoch(row.expenseDate),
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      );
    }).toList();
  }

  Future<void> saveExpense({
    String? id,
    required String description,
    required String category,
    required int amountCentavos,
    required String? paymentMethod,
    required DateTime expenseDate,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final expenseId = id ?? _uuid.v4();

    if (id == null) {
      await database
          .into(database.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: expenseId,
              description: description.trim(),
              category: category,
              amountCentavos: amountCentavos,
              paymentMethod: Value(paymentMethod),
              expenseDate: expenseDate.millisecondsSinceEpoch,
              createdAt: now,
            ),
          );
      return;
    }

    await (database.update(
      database.expenses,
    )..where((expense) => expense.id.equals(expenseId))).write(
      ExpensesCompanion(
        description: Value(description.trim()),
        category: Value(category),
        amountCentavos: Value(amountCentavos),
        paymentMethod: Value(paymentMethod),
        expenseDate: Value(expenseDate.millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> deleteExpense(String id) async {
    await (database.delete(
      database.expenses,
    )..where((expense) => expense.id.equals(id))).go();
  }
}
